# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::TagsController, type: :controller do
  describe 'GET #index' do
    let!(:tag_crypto) { create(:tag, title: 'Cryptocurrency') }
    let!(:tag_bitcoin) { create(:tag, title: 'Bitcoin') }
    let!(:tag_ethereum) { create(:tag, title: 'Ethereum') }

    context 'when nobody is signed in' do
      it 'refuses — this feeds the editor tag picker and nothing public' do
        get :index, params: { locale: 'uk', term: 'coin' }

        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'when a reader without staff rights is signed in' do
      it 'refuses' do
        sign_in create(:user, role: :user)

        get :index, params: { locale: 'uk', term: 'coin' }

        expect(response).to redirect_to(root_path)
      end
    end

    context 'when a staff member is signed in' do
      before { sign_in create(:user, role: :admin) }

      it 'returns matching tags serialized with TagBlueprint' do
        get :index, params: { locale: 'uk', term: 'coin' }

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body

        # 'Bitcoin' contains 'coin'
        expect(json_response.length).to eq(1)
        expect(json_response.first['title']).to eq('Bitcoin')
        expect(json_response.first['id']).to eq(tag_bitcoin.id)
      end

      it 'performs a matching search' do
        get :index, params: { locale: 'uk', term: 'Crypt' }

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body

        expect(json_response.length).to eq(1)
        expect(json_response.first['title']).to eq('Cryptocurrency')
        expect(json_response.first['id']).to eq(tag_crypto.id)
      end

      it 'returns all tags for a blank term' do
        get :index, params: { locale: 'uk', term: '' }

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body

        expect(json_response.length).to eq(3)
        titles = json_response.pluck('title')
        expect(titles).to include('Cryptocurrency', 'Bitcoin', 'Ethereum')
      end

      it 'treats LIKE wildcards in the term as characters, not as wildcards' do
        create(:tag, title: 'a_b')

        get :index, params: { locale: 'uk', term: '_' }

        titles = response.parsed_body.pluck('title')
        expect(titles).to contain_exactly('a_b')
      end

      it 'caps how many suggestions it returns' do
        create_list(:tag, Api::TagsController::LIMIT + 5)

        get :index, params: { locale: 'uk', term: '' }

        expect(response.parsed_body.length).to eq(Api::TagsController::LIMIT)
      end
    end
  end
end
