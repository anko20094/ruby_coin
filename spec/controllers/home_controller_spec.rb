# frozen_string_literal: true

require 'rails_helper'

describe HomeController, type: :request do
  let!(:post) { create(:post, status: 'active') }
  let!(:ruby_post) { create(:post, title: 'Ruby on Rails') }
  let!(:inactive_ruby_post) { create(:post, title: 'Ruby on Jets', status: 'inactive') }

  describe 'GET #index' do
    it 'returns a successful response and renders the index template' do
      get root_path

      expect(response).to be_successful
      expect(response).to render_template(:index)
    end
  end

  describe 'GET #search' do
    it 'returns a successful response and renders the search template' do
      get search_path

      expect(response).to be_successful
      expect(response).to render_template(:search)
    end

    it 'returns a successful response and show correct results' do
      get search_path(query: 'ruby')

      expect(response).to be_successful
      expect(response).to render_template(:search)

      expect(response.body).to include(ruby_post.title)
      expect(response.body).not_to include(inactive_ruby_post.title)
    end
  end
end
