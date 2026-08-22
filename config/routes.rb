# frozen_string_literal: true

Rails.application.routes.draw do
  mount ActionCable.server, at: '/cable'
  mount Lookbook::Engine, at: '/lookbook' if Rails.env.development?

  scope '/(:locale)', locale: /uk|en/ do
    devise_for :users, controllers: {
      registrations: 'users/registrations',
      sessions: 'users/sessions'
    }

    root 'home#index'
    get '/search', to: 'home#search'

    # /journal is the article stream on the new theme. /post/:id stays the canonical post
    # URL so indexed links and FriendlyId's slug history keep resolving.
    get '/journal', to: 'journal#index', as: 'journal'
    get '/faq', to: 'faq#index'

    # /work — portfolio section. The index doubles as the CV, so /cv is gone.
    get '/work', to: 'work#index', as: 'work'
    get '/work/:slug', to: 'work#show', as: 'work_case'
    work = ->(params) { params[:locale].present? ? "/#{params[:locale]}/work" : '/work' }
    get '/cv', to: redirect(status: 301) { |params, _request| work.call(params) }

    # The redesigned nav carries four sections; these two are not built yet.
    get '/studio', to: redirect { |params, _request| work.call(params) }, as: 'studio'
    get '/contact', to: redirect { |params, _request| "#{work.call(params)}#contact" }, as: 'contact'
    get '/post/:id', to: 'journal#show', as: 'post'
    get 'set_locale', to: 'application#set_locale'

    namespace :management do
      root 'posts#index', as: 'root'
      get 'statistics/index', to: 'statistics#index', as: 'statistics'

      resources :posts do
        post 'translate', on: :collection
      end

      resources :tags
      # The slash menu posts here to mint a block and get its sgid back.
      resources :journal_blocks, only: :create
    end

    namespace :api do
      resources :tags, only: :index
    end
  end
end
