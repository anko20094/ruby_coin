# frozen_string_literal: true

Rails.application.routes.draw do
  mount Lookbook::Engine, at: '/lookbook' if Rails.env.development?

  # config.exceptions_app sends failures back through the router at these paths. They sit
  # outside the /(:locale) scope because that is where Rails puts them: ErrorsController
  # recovers the reader's language from the address they actually asked for.
  # A sitemap lists both locales, so it is one document outside the locale scope. robots.txt
  # is dynamic so the Sitemap: line carries the real host rather than a guess in a static file.
  get '/sitemap.xml', to: 'feeds#sitemap', as: :sitemap, defaults: { format: :xml }
  get '/robots.txt', to: 'feeds#robots', as: :robots, defaults: { format: :text }

  match '/404', to: 'errors#not_found', via: :all
  match '/422', to: 'errors#unacceptable', via: :all
  match '/500', to: 'errors#internal_error', via: :all

  # Every locale lives in the path. The constraint is anchored to the whole segment, so
  # /enterprise is a 404 rather than the home page under a nonsense locale.
  scope '/(:locale)', locale: /uk|en/ do
    devise_for :users, controllers: { registrations: 'users/registrations' }

    # / is still the old article stream. The redesigned home page takes it over in W7b, and
    # that is when the §4.3 redirects for /?page= and /?tag_ids[] make sense — not before.
    root 'home#index'

    # /journal is the article stream on the new theme. /post/:id stays the canonical post URL
    # so indexed links and FriendlyId's slug history keep resolving.
    get '/journal', to: 'journal#index', as: 'journal'
    get '/post/:id', to: 'journal#show', as: 'post'
    # Kept at /search rather than /journal/search: the URL is indexed, and it is the address
    # the command palette's "see all results" points at.
    get '/search', to: 'journal#search', as: 'search'
    # One feed per language, at the address the footer advertises.
    get '/feed', to: 'feeds#feed', as: :feed, defaults: { format: :atom }

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

      # No show screen: the list is the screen, and editing is where a post is looked at.
      # It used to be routed at a template that rendered a partial deleted years ago, so
      # every "delete" link in the list — a GET to this URL, because Turbo Drive is off —
      # landed on a 500.
      resources :posts, except: :show do
        post 'translate', on: :collection
        # The editor autosaves here and reloads the preview frame afterwards.
        patch 'autosave', on: :member
        get 'preview', on: :member
      end

      # None of these three has a show action — the list is the screen — so the route is not
      # generated either.
      resources :tags, except: :show
      resources :cases, except: :show

      # No CV route. The CV is config/portfolio/cv.yml, imported by `rake cv:import` — the
      # one piece of content here whose history matters, and git keeps that better than a
      # JSONB column. See redesign_plan.md §12.5.

      # The editor's block menu posts here to mint a block and get its sgid back.
      resources :journal_blocks, only: :create

      # TinyMCE's image button uploads here and gets a URL back.
      resources :editor_images, only: :create
    end

    # Read by the tag pickers in the admin forms.
    namespace :api do
      resources :tags, only: :index
    end
  end
end
