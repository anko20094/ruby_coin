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

    it 'renders the form with one field per language and the declared row counts' do
      get edit_management_case_path(kase, locale: 'en')

      expect(response.body).to include('case[title_en]', 'case[title_uk]')
      expect(response.body).to include('case[metrics_rows][0][value]', 'case[metrics_rows][0][label][en]')
      # Four drawn by the design, plus a spare row to add one.
      expect(response.body.scan(/case\[metrics_rows\]\[\d+\]\[value\]/).size).to eq(5)
      expect(response.body.scan(/case\[engineering_items_rows\]\[\d+\]\[title\]\[en\]/).size).to eq(7)
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
        '0' => { 'value' => '1', 'label' => { 'en' => 'one', 'uk' => 'один' } },
        '1' => { 'value' => '', 'label' => { 'en' => '', 'uk' => '' } }
      }

      patch management_case_path(kase, locale: 'en'), params: { case: { metrics_rows: rows } }

      expect(kase.reload[:metrics]).to eq([{ 'value' => '1', 'label' => { 'en' => 'one', 'uk' => 'один' } }])
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
