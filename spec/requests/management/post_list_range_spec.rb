# frozen_string_literal: true

require 'rails_helper'

describe 'the admin post list past its last page', type: :request do
  include_context 'when carrierwave cleanup'

  around { |example| I18n.with_locale(:en) { example.run } }

  before do
    stub_const('Management::PostsController::PER_PAGE', 2)
    sign_in create(:user, role: :admin)
  end

  context 'with entries' do
    before { 5.times { |index| create(:post, status: 'active', title: "Range entry #{index}") } }

    it 'sends a page past the end to the last one' do
      get management_posts_path(locale: 'en', page: 9)

      expect(response).to redirect_to(management_posts_path(locale: 'en', page: 3))
    end

    it 'keeps the filter and the sort on the way' do
      get management_posts_path(locale: 'en', status: 'active', sort: 'number', direction: 'asc', page: 9)

      expect(response).to redirect_to(
        management_posts_path(locale: 'en', status: 'active', sort: 'number', direction: 'asc', page: 3)
      )
    end

    it 'sends a page too large for the database to the last one' do
      get management_posts_path(locale: 'en', page: '99999999999999999999')

      expect(response).to redirect_to(management_posts_path(locale: 'en', page: 3))
    end

    it 'sends a page past the end of a filtered list to the last page of that list' do
      create(:post, status: 'inactive', title: 'Range hidden')

      get management_posts_path(locale: 'en', status: 'inactive', page: 4)

      expect(response).to redirect_to(management_posts_path(locale: 'en', status: 'inactive', page: 1))
    end

    it 'renders the last page itself' do
      get management_posts_path(locale: 'en', page: 3)

      expect(response).to be_successful
      expect(response.parsed_body.css('.mg-table tbody tr').size).to eq(1)
    end
  end

  context 'without entries' do
    it 'shows the empty state on the first page, not a redirect' do
      get management_posts_path(locale: 'en')

      expect(response).to be_successful
      expect(response.parsed_body.at_css('.mg-empty')).to be_present
    end

    it 'sends any other page to the first, once' do
      get management_posts_path(locale: 'en', page: 2)

      expect(response).to redirect_to(management_posts_path(locale: 'en', page: 1))
    end
  end
end
