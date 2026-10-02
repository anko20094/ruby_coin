# frozen_string_literal: true

require 'rails_helper'

describe 'the admin case screens', type: :request do
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
      expect(response.body.scan('class="mg-case-row"').size).to eq(7)
      expect(response.body.index('intelligence')).to be < response.body.index('rubycoin')
    end

    it 'renders one field per language, and a row per row the case actually has' do
      get edit_management_case_path(kase, locale: 'en')

      expect(response.body).to include('case[title_en]', 'case[title_uk]')
      expect(response.body).to include('case[metrics_rows][0][value][en]', 'case[metrics_rows][0][label][en]')

      # As many rows as the case holds, two inputs (en/uk) each; the <template> row's index is
      # StructuredRowsHelper::ROW_INDEX, not a number, so it is not counted.
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

      # /work renders these through ProseHelper#rich; a metric's figure is printed as a plain number.
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

    it 'gives the prose fields an editor and year, sector and status a plain input' do
      get edit_management_case_path(kase, locale: 'en')

      form = response.parsed_body

      Case::PLAIN_SCALARS.each do |field|
        input = form.at_css("#case_#{field}_en")
        expect([input.name, input['data-controller']]).to eq(['input', nil])
      end
      expect(Case::RICH_SCALARS.map { |field| form.at_css("#case_#{field}_en")['data-controller'] }.uniq)
        .to eq(['tinymce'])
    end

    it 'tells each editor the language it holds and the markup it may produce' do
      get edit_management_case_path(kase, locale: 'en')

      form = response.parsed_body
      allowed = ApplicationController.helpers.tinymce_valid_elements

      expect(form.at_css('#case_title_uk')['data-tinymce-lang-value']).to eq('uk')
      expect(form.at_css('#case_title_uk')['data-tinymce-valid-elements-value']).to eq(allowed)
      expect(form.at_css('[name="case[metrics_rows][0][label][en]"]')['data-tinymce-lang-value']).to eq('en')
      expect(form.at_css('[name="case[mine_rows][0][uk]"]')['data-tinymce-lang-value']).to eq('uk')
    end

    it 'names the field as well as the language in the label of every box' do
      get edit_management_case_path(kase, locale: 'en')

      form = response.parsed_body

      expect(form.at_css('label[for=case_title_en]').text).to eq('Title · english')
      expect(form.at_css('label[for=case_sector_uk]').text).to eq('Sector · ukrainian')
    end

    it 'carries the version it was loaded at and asks before the page is left with work in it' do
      get edit_management_case_path(kase, locale: 'en')

      form = response.parsed_body

      expect(form.at_css('input[name="case[lock_version]"]')['value']).to eq(kase.lock_version.to_s)
      guarded = form.at_css('form[data-controller="unsaved-guard"]')
      expect(guarded.at_css('#case_title_en')).to be_present
      expect(guarded['data-action']).to include('input->unsaved-guard#mark', 'submit->unsaved-guard#release')
    end

    it 'names every list in the form, so that one emptied of its rows is read as emptied' do
      get edit_management_case_path(kase, locale: 'en')

      names = response.parsed_body.css('input[name="case[structures][]"]').pluck('value')

      expect(names).to eq(Case::STRUCTURES.keys.map(&:to_s))
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

    it 'empties a list whose rows were all removed, and only that one' do
      patch management_case_path(kase, locale: 'en'), params: { case: { structures: ['mine'] } }

      expect(kase.reload[:mine]).to eq([])
      expect(kase[:metrics]).to be_present
    end

    it 'leaves every list alone when the request does not name it' do
      expect { patch management_case_path(kase, locale: 'en'), params: { case: { mark: '01' } } }
        .not_to(change { kase.reload.slice(*Case::STRUCTURES.keys) })
    end

    it 'takes a name that is not a list for nothing' do
      patch management_case_path(kase, locale: 'en'), params: { case: { structures: %w[slug title] } }

      expect(response).to redirect_to(management_cases_path)
      expect(kase.reload.slug).to eq('dna')
    end

    it 'stores year, sector and status exactly as typed' do
      patch management_case_path(kase, locale: 'en'),
            params: { case: { year_en: '2022—present', sector_en: 'publishing · education & more' } }

      expect(kase.reload[:year]['en']).to eq('2022—present')
      expect(kase[:sector]['en']).to eq('publishing · education & more')
    end

    it 'edits and writes a case whose year is one plain string for both languages' do
      kase.update_columns(year: '2023—2026')

      get edit_management_case_path(kase, locale: 'en')

      expect(response).to be_successful
      expect(response.parsed_body.at_css('#case_year_uk')['value']).to eq('2023—2026')

      patch management_case_path(kase, locale: 'en'), params: { case: { year_en: '2023—2027' } }

      expect(kase.reload[:year]).to eq({ 'en' => '2023—2027', 'uk' => '2023—2026' })
    end

    it 'refuses a position that cannot be stored, rather than failing on it' do
      %w[99999999999 0 soon].each do |position|
        patch management_case_path(kase, locale: 'en'), params: { case: { position: position } }

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context 'when a second tab saves from a form that was opened before the first one saved' do
      let(:opened_at) { kase.lock_version }

      def patch_case(**attributes)
        patch management_case_path(kase, locale: 'en'), params: { case: attributes }
      end

      before do
        opened_at
        patch_case(tagline_en: 'first tab', lock_version: opened_at)
        patch_case(role_en: 'second tab', lock_version: opened_at)
      end

      it 'writes nothing, so the first tab keeps its edit' do
        expect(response).to have_http_status(:conflict)
        expect(kase.reload.tagline_en).to eq('first tab')
        expect(kase.role_en).not_to eq('second tab')
      end

      it 'hands the second tab its own text back, at the version that is current' do
        form = response.parsed_body

        expect(form.at_css('#case_role_en').text).to include('second tab')
        expect(form.at_css('input[name="case[lock_version]"]')['value']).to eq(kase.reload.lock_version.to_s)
      end
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

    it 'deletes a case nobody is credited on' do
      Case.find_by!(slug: 'dna').dup.tap { |copy| copy.slug = 'scratch' }.save!

      expect { delete management_case_path(Case.find_by!(slug: 'scratch'), locale: 'en') }
        .to change(Case, :count).by(-1)
    end

    it 'keeps a case that team.yml credits, and says why' do
      expect { delete management_case_path(kase, locale: 'en') }.not_to change(Case, :count)

      expect(response).to redirect_to(management_cases_path)
      expect(flash[:alert]).to include('team.yml')
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
end
