# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Routes' do
  describe 'GET /' do
    it 'routes to home#index' do
      expect(get: '/').to route_to('home#index')
    end
  end

  describe 'GET /search' do
    it 'routes to journal#search — search is the journal searching itself' do
      expect(get: '/search').to route_to('journal#search')
    end
  end

  describe 'GET /faq' do
    it 'routes to faq#index' do
      expect(get: '/faq').to route_to('faq#index')
    end
  end

  describe 'GET /work' do
    it 'routes to work#index' do
      expect(get: '/work').to route_to('work#index')
    end
  end

  describe 'GET /work/:slug' do
    it 'routes to work#show' do
      expect(get: '/work/dna').to route_to('work#show', slug: 'dna')
    end
  end

  describe 'GET /journal' do
    it 'routes to journal#index' do
      expect(get: '/journal').to route_to('journal#index')
    end
  end

  describe 'GET /post/1' do
    it 'routes to journal#show' do
      expect(get: '/post/1').to route_to('journal#show', id: '1')
    end
  end

  describe 'GET /management' do
    it 'routes to management/posts#index' do
      expect(get: '/management').to route_to('management/posts#index')
    end
  end

  describe 'GET /management/posts' do
    it 'routes to management/posts#index' do
      expect(get: '/management/posts').to route_to('management/posts#index')
    end
  end

  describe 'GET /management/tags' do
    it 'routes to management/tags#index' do
      expect(get: '/management/tags').to route_to('management/tags#index')
    end
  end

  describe 'GET /api/tags' do
    it 'routes to api/tags#index' do
      expect(get: '/api/tags').to route_to('api/tags#index')
    end
  end

  # Users::SessionsController was 100% commented-out boilerplate, so the devise_for override
  # pointed at a class that added nothing. Devise's own controller answers now.
  describe 'Devise routes' do
    describe 'GET /users/sign_up' do
      it 'routes to users/registrations#new' do
        expect(get: '/users/sign_up').to route_to('users/registrations#new')
      end
    end

    describe 'POST /users' do
      it 'routes to users/registrations#create' do
        expect(post: '/users').to route_to('users/registrations#create')
      end
    end

    describe 'GET /users/sign_in' do
      it 'routes to users/sessions#new' do
        expect(get: '/users/sign_in').to route_to('devise/sessions#new')
      end
    end

    describe 'POST /users/sign_in' do
      it 'routes to users/sessions#create' do
        expect(post: '/users/sign_in').to route_to('devise/sessions#create')
      end
    end

    describe 'DELETE /users/sign_out' do
      it 'routes to users/sessions#destroy' do
        expect(delete: '/users/sign_out').to route_to('devise/sessions#destroy')
      end
    end
  end

  describe 'routes that are deliberately absent' do
    # These three screens are a list and its forms; there is no show action behind them, so
    # there should be no route pretending otherwise.
    it 'has no show route for the admin lists' do
      expect(get: '/management/cases/1').not_to be_routable
      expect(get: '/management/cv_blocks/1').not_to be_routable
      expect(get: '/management/tags/1').not_to be_routable
    end

    # ApplicationController#set_locale was removed when the locale handling moved into the
    # around_action; the route outlived the action by a while.
    it 'has no set_locale route' do
      expect(get: '/set_locale').not_to be_routable
    end

    # Nothing in the app opens a cable connection — no turbo_stream_from anywhere.
    it 'does not mount ActionCable' do
      expect(get: '/cable').not_to be_routable
    end
  end

  describe 'GET /management/statistics' do
    it 'routes to management/statistics#index without an /index suffix' do
      expect(get: '/management/statistics').to route_to('management/statistics#index')
      expect(get: '/management/statistics/index').not_to be_routable
    end
  end
end
