# frozen_string_literal: true

require 'rails_helper'

# Feeds the editor tag picker and nothing public. Signed out is in anonymous_access_spec.
describe 'GET /api/tags', type: :request do
  let!(:tag_crypto) { create(:tag, title: 'Cryptocurrency') }
  let!(:tag_bitcoin) { create(:tag, title: 'Bitcoin') }

  before { create(:tag, title: 'Ethereum') }

  def suggest(term) = get(api_tags_path(locale: 'uk', term:))

  it 'refuses a reader without staff rights' do
    sign_in create(:user, role: :user)

    suggest('coin')

    expect(response).to redirect_to(root_path)
  end

  context 'when a staff member is signed in' do
    before { sign_in create(:user, role: :admin) }

    it 'returns matching tags serialized with TagBlueprint' do
      suggest('coin')

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq([{ 'id' => tag_bitcoin.id, 'title' => 'Bitcoin' }])
    end

    it 'performs a matching search' do
      suggest('Crypt')

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq([{ 'id' => tag_crypto.id, 'title' => 'Cryptocurrency' }])
    end

    it 'returns all tags for a blank term' do
      suggest('')

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.pluck('title')).to contain_exactly('Cryptocurrency', 'Bitcoin', 'Ethereum')
    end

    it 'treats LIKE wildcards in the term as characters, not as wildcards' do
      create(:tag, title: 'a_b')

      suggest('_')

      expect(response.parsed_body.pluck('title')).to contain_exactly('a_b')
    end

    it 'caps how many suggestions it returns' do
      create_list(:tag, Api::TagsController::LIMIT + 5)

      suggest('')

      expect(response.parsed_body.length).to eq(Api::TagsController::LIMIT)
    end
  end
end
