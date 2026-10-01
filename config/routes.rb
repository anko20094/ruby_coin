# frozen_string_literal: true

Rails.application.routes.draw do
  mount Lookbook::Engine, at: '/lookbook' if Rails.env.development?

  # A sitemap lists both locales, so it is one document outside the locale scope. robots.txt
  # is dynamic so the Sitemap: line carries the real host rather than a guess in a static file.
  get '/sitemap.xml', to: 'feeds#sitemap', as: :sitemap, defaults: { format: :xml }
  get '/robots.txt', to: 'feeds#robots', as: :robots, defaults: { format: :text }

  # config.exceptions_app sends failures back through the router at these paths. They sit
  # outside the /(:locale) scope because that is where Rails puts them: ErrorsController
  # recovers the reader's language from the address they actually asked for.
  match '/404', to: 'errors#not_found', via: :all
  match '/422', to: 'errors#unacceptable', via: :all
  match '/500', to: 'errors#internal_error', via: :all

  # Every locale lives in the path. The constraint is anchored to the whole segment, so
  # /enterprise is a 404 rather than the home page under a nonsense locale.
  scope '/(:locale)', locale: /uk|en/ do
    devise_for :users, skip: :registrations
    devise_scope :user do
      resource :registration, only: %i[new create edit update], path: 'users', path_names: { new: 'sign_up' },
                              as: :user_registration, controller: 'users/registrations'
    end

    # A page has one address: `format: false` on the pages below keeps /.env, /en.foo and
    # /en/work.foo from answering 200 as copies of it. Only the palette's JSON and the feed's
    # Atom name a format.
    root 'home#index', format: false

    # /journal is the article stream on the new theme. /post/:id stays the canonical post URL
    # so indexed links and FriendlyId's slug history keep resolving.
    get '/journal', to: 'journal#index', as: 'journal', format: false
    get '/post/:id', to: 'journal#show', as: 'post', format: false
    # Kept at /search rather than /journal/search: the URL is indexed, and it is the address
    # the command palette's "see all results" points at.
    get '/search', to: 'journal#search', as: 'search', constraints: { format: /json/ }
    # One feed per language, at the address the footer advertises.
    get '/feed', to: 'feeds#feed', as: :feed, format: 'atom'

    # /work — the portfolio, in three levels: the projects, one project, one person.
    get '/work', to: 'work#index', as: 'work', format: false
    get '/work/:slug', to: 'work#show', as: 'work_case', format: false

    # One person, one page. /work/:slug/team/:person would be seven projects times six people
    # of duplicated CV, so the project a reader arrived through travels as ?from=:slug — a
    # query parameter, because it has to survive being pasted into a chat.
    get '/team', to: 'team#index', as: 'team', format: false
    get '/team/:id', to: 'team#show', as: 'person', format: false

    # /cv is a page, not a redirect to /work. It was one while /work carried the CV; /work
    # stopped being one person's frame the moment six people appeared on it.
    get '/cv', to: 'cv#show', as: 'cv', format: false

    get '/contact', to: 'contact#show', as: 'contact', format: false
    get '/faq', to: 'faq#index', format: false
    get '/studio', to: 'studio#show', as: 'studio', format: false

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
