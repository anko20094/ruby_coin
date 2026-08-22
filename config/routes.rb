# frozen_string_literal: true

Rails.application.routes.draw do
  mount Lookbook::Engine, at: '/lookbook' if Rails.env.development?

  # Every locale lives in the path. The constraint is anchored to the whole segment, so
  # /enterprise is a 404 rather than the home page under a nonsense locale.
  scope '/(:locale)', locale: /uk|en/ do
    devise_for :users, controllers: {
      registrations: 'users/registrations',
      sessions: 'users/sessions'
    }

    # / is still the old article stream. The redesigned home page takes it over in W7b, and
    # that is when the §4.3 redirects for /?page= and /?tag_ids[] make sense — not before.
    root 'home#index'
    get '/search', to: 'home#search'

    # /journal is the article stream on the new theme. /post/:id stays the canonical post URL
    # so indexed links and FriendlyId's slug history keep resolving.
    get '/journal', to: 'journal#index', as: 'journal'
    get '/post/:id', to: 'journal#show', as: 'post'

    # /work — portfolio section. The index doubles as the CV, so /cv is gone for good: 301.
    get '/work', to: 'work#index', as: 'work'
    get '/work/:slug', to: 'work#show', as: 'work_case'
    work = ->(params) { params[:locale].present? ? "/#{params[:locale]}/work" : '/work' }
    get '/cv', to: redirect(status: 301) { |params, _request| work.call(params) }

    get '/contact', to: 'contact#show', as: 'contact'
    get '/faq', to: 'faq#index'

    # /studio waits on real team data — the handoff forbids placeholder people. 302, not the
    # 301 that `redirect` defaults to: this page is coming, and a permanent redirect would
    # still be cached in browsers and search engines on the day it lands.
    get '/studio', to: redirect(status: 302) { |params, _request| work.call(params) }, as: 'studio'

    namespace :management do
      root 'posts#index', as: 'root'
      get 'statistics', to: 'statistics#index', as: 'statistics'

      resources :posts do
        post 'translate', on: :collection
        # The editor autosaves here and reloads the preview frame afterwards.
        patch 'autosave', on: :member
        get 'preview', on: :member
      end

      # None of these three has a show action — the list is the screen — so the route is not
      # generated either.
      resources :tags, except: :show
      resources :cases, except: :show
      resources :cv_blocks, except: :show

      # The CV frame is one row, so it has one screen rather than a collection.
      resource :cv_profile, only: %i[edit update]

      # The slash menu posts here to mint a block and get its sgid back.
      resources :journal_blocks, only: :create
    end

    # Read by the tag pickers in the admin forms.
    namespace :api do
      resources :tags, only: :index
    end
  end
end
