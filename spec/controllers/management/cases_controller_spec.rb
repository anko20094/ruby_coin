# frozen_string_literal: true

require 'rails_helper'

describe Management::CasesController, type: :request do
  include_context 'when the cases are imported'

  let(:admin) { create(:user, role: :admin) }
  let(:kase) { Case.find_by!(slug: 'dna') }

  def valid_attributes
    attributes = { slug: 'new-case', mark: '08', position: 8, year: '2026', sector: 'tools', status: 'in progress' }
    Case::LOCALISED_SCALARS.each do |field|
      attributes[:"#{field}_en"] = "#{field} in english"
      attributes[:"#{field}_uk"] = "#{field} українською"
    end
    attributes
  end

  context 'when an admin is signed in' do
    before { sign_in(admin) }

    it 'lists the cases in display order' do
      get management_cases_path(locale: 'en')

      expect(response).to be_successful
      expect(response.body.scan('class="case-row"').size).to eq(7)
      expect(response.body.index('intelligence')).to be < response.body.index('rubycoin')
    end

    it 'renders one field per language, and a row per row the case actually has' do
      get edit_management_case_path(kase, locale: 'en')

      expect(response.body).to include('case[title_en]', 'case[title_uk]')
      expect(response.body).to include('case[metrics_rows][0][value][en]', 'case[metrics_rows][0][label][en]')

      # What the case holds — not Case::STRUCTURES[:count] and not that plus a spare. The form
      # used to draw a fixed number of rows and there was no way to have any other number; the
      # count is a hint beside the heading now, and the rows are added and removed on screen.
      # The <template> row is not counted here: its index is StructuredRowsHelper::ROW_INDEX, not a
      # number, which is exactly what tells the two apart.
      # Two inputs per row now: a figure is written differently in the two languages, so it
      # carries a language pair like the label beside it.
      expect(response.body.scan(/case\[metrics_rows\]\[\d+\]\[value\]\[\w+\]/).size)
        .to eq(kase.metrics_rows.size * I18n.available_locales.size)
      expect(response.body).to include('data-controller="structure-rows"')
    end

    it 'draws the design\'s row count for a case that has none yet' do
      get new_management_case_path(locale: 'en')

      # Plus one: the <template> the add button clones carries a row of its own.
      expected = Case::STRUCTURES.fetch(:metrics).fetch(:count) * I18n.available_locales.size
      expect(response.body.scan(/case\[metrics_rows\]\[\d+\]\[value\]\[\w+\]/).size).to eq(expected)
      expect(response.body).to include(StructuredRowsHelper::ROW_INDEX)
    end

    it 'gives every localised field an editor and every plain one a plain input' do
      get edit_management_case_path(kase, locale: 'en')

      form = response.parsed_body

      # The /work page renders these strings through ProseHelper#rich, so an author needs a way
      # to make markup. A metric's figure is not one of them: it is printed as a number and
      # copied to the clipboard as one.
      title = form.at_css('#case_title_en')
      expect(title.name).to eq('textarea')
      expect(title['data-controller']).to eq('tinymce')
      # Lazily, or a case form boots sixty editors to type in one.
      expect(title['data-tinymce-lazy-value']).to eq('true')

      figure = form.at_css('[name="case[metrics_rows][0][value][en]"]')
      expect(figure.name).to eq('input')
      expect(figure['data-controller']).to be_nil

      # Every cloned row needs an id of its own or TinyMCE will not start on the second one.
      template_ids = form.css('template [id]').pluck('id')
      expect(template_ids).to all(include(StructuredRowsHelper::ROW_INDEX))
    end

    it 'creates a case' do
      expect { post management_cases_path(locale: 'en'), params: { case: valid_attributes } }
        .to change(Case, :count).by(1)

      expect(Case.find_by!(slug: 'new-case')[:title])
        .to eq({ 'en' => 'title in english', 'uk' => 'title українською' })
    end

    it 'refuses a case written in one language only' do
      attributes = valid_attributes.except(*Case::LOCALISED_SCALARS.map { |field| :"#{field}_uk" })

      expect { post management_cases_path(locale: 'en'), params: { case: attributes } }
        .not_to change(Case, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'updates the structured fields from the form, dropping the empty row' do
      rows = {
        '0' => { 'value' => { 'en' => '1', 'uk' => '1' }, 'label' => { 'en' => 'one', 'uk' => 'один' } },
        '1' => { 'value' => { 'en' => '', 'uk' => '' }, 'label' => { 'en' => '', 'uk' => '' } }
      }

      patch management_case_path(kase, locale: 'en'), params: { case: { metrics_rows: rows } }

      expect(kase.reload[:metrics])
        .to eq([{ 'value' => { 'en' => '1', 'uk' => '1' }, 'label' => { 'en' => 'one', 'uk' => 'один' } }])
    end

    it 'edits the stack as one item per line' do
      patch management_case_path(kase, locale: 'en'),
            params: { case: { stack_list: "Rails\n  Postgres  \n\nSolid Queue" } }

      expect(kase.reload[:stack]).to eq(['Rails', 'Postgres', 'Solid Queue'])
    end

    it 'keeps a key the form did not declare out of the column' do
      rows = { '0' => { 'value' => '9', 'label' => { 'en' => 'nine', 'uk' => 'девʼять' }, 'sneaky' => 'x' } }

      patch management_case_path(kase, locale: 'en'), params: { case: { metrics_rows: rows } }

      expect(kase.reload[:metrics].first.keys).to contain_exactly('value', 'label')
    end

    it 'deletes a case' do
      expect { delete management_case_path(kase, locale: 'en') }.to change(Case, :count).by(-1)
    end
  end

  context 'when a moderator is signed in' do
    before { sign_in(create(:user, role: :moderator)) }

    it 'may look at the list' do
      get management_cases_path(locale: 'en')

      expect(response).to be_successful
    end

    it 'may not create one' do
      expect { post management_cases_path(locale: 'en'), params: { case: valid_attributes } }
        .not_to change(Case, :count)
    end
  end

  context 'when nobody is signed in' do
    it 'sends them to sign in' do
      get management_cases_path(locale: 'en')

      expect(response).to redirect_to(new_user_session_path(locale: I18n.default_locale))
    end
  end
end
