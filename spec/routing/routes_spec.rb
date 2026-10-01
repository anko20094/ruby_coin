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

  describe 'GET /team' do
    it 'routes to team#index' do
      expect(get: '/team').to route_to('team#index')
    end
  end

  describe 'GET /team/:id' do
    it 'routes to team#show' do
      expect(get: '/team/danyil').to route_to('team#show', id: 'danyil')
    end
  end

  # One person, one page. Seven projects times six people would be 42 URLs of the same CV, so
  # the project a reader arrived through travels as ?from= instead.
  describe 'GET /work/:slug/team/:person' do
    it 'is deliberately absent' do
      expect(get: '/work/dna/team/danyil').not_to be_routable
    end
  end

  describe 'GET /cv' do
    it 'routes to cv#show, and is a page rather than a redirect to /work' do
      expect(get: '/cv').to route_to('cv#show')
    end
  end

  describe 'GET /studio' do
    it 'routes to studio#show' do
      expect(get: '/studio').to route_to('studio#show')
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

  describe 'the admin writes' do
    it 'routes the editor calls on a post, each to its own verb' do
      expect(post: '/management/posts/translate').to route_to('management/posts#translate')
      expect(patch: '/management/posts/1/autosave').to route_to('management/posts#autosave', id: '1')
      expect(get: '/management/posts/1/preview').to route_to('management/posts#preview', id: '1')
    end

    it 'routes create, update and destroy on every admin list' do
      %w[posts tags cases].each do |list|
        expect(post: "/management/#{list}").to route_to("management/#{list}#create")
        expect(patch: "/management/#{list}/1").to route_to("management/#{list}#update", id: '1')
        expect(delete: "/management/#{list}/1").to route_to("management/#{list}#destroy", id: '1')
      end
    end

    it 'routes what the editor mints and uploads' do
      expect(post: '/management/journal_blocks').to route_to('management/journal_blocks#create')
      expect(post: '/management/editor_images').to route_to('management/editor_images#create')
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
      it 'routes to devise/sessions#new' do
        expect(get: '/users/sign_in').to route_to('devise/sessions#new')
      end
    end

    describe 'POST /users/sign_in' do
      it 'routes to devise/sessions#create' do
        expect(post: '/users/sign_in').to route_to('devise/sessions#create')
      end
    end

    describe 'DELETE /users/sign_out' do
      it 'routes to devise/sessions#destroy' do
        expect(delete: '/users/sign_out').to route_to('devise/sessions#destroy')
      end
    end
  end

  describe 'the locale segment' do
    it 'is uk or en, and is optional' do
      expect(get: '/uk/work').to route_to('work#index', locale: 'uk')
      expect(get: '/en/work').to route_to('work#index', locale: 'en')
      expect(get: '/work').to route_to('work#index')
    end

    it 'is matched as a whole segment, so a longer word is not a locale' do
      expect(get: '/enterprise').not_to be_routable
      expect(get: '/ukraine/work').not_to be_routable
      expect(get: '/de/work').not_to be_routable
    end
  end

  describe 'routes that are deliberately absent' do
    # These three screens are a list and its forms; there is no show action behind them, so
    # there should be no route pretending otherwise.
    it 'has no show route for the admin lists' do
      expect(get: '/management/cases/1').not_to be_routable
      expect(get: '/management/cv_blocks').not_to be_routable
      expect(get: '/management/cv_profile/edit').not_to be_routable
      expect(get: '/management/cv_blocks/1').not_to be_routable
      expect(get: '/management/tags/1').not_to be_routable
    end

    # ApplicationController#set_locale was removed when the locale handling moved into the
    # around_action; the route outlived the action by a while.
    it 'has no set_locale route' do
      expect(get: '/set_locale').not_to be_routable
    end

    # Nothing in the app opens a cable connection — no turbo_stream_from anywhere. A mounted
    # Rack app is never recognised as a controller route, so only the route table can tell.
    it 'does not mount ActionCable' do
      mounted = Rails.application.routes.routes.map { |route| route.path.spec.to_s }

      expect(mounted.grep(%r{\A/cable})).to be_empty
      expect(Rails.application.config.action_cable.mount_path).to be_nil
      expect(get: '/cable').not_to be_routable
    end
  end

  # A page has one address. Every route used to take an optional extension, so /.env, /en.foo
  # and /en/work.foo answered 200 with a copy of a page that named itself canonical.
  describe 'pages and their extensions' do
    %w[
      /.env /en.foo /en/work.foo /en/work/dna.foo /en/team/danyil.foo /en/journal.foo /en/post/a-post.foo
      /en/cv.foo /en/contact.foo /en/faq.foo /en/studio.foo /en/team.foo
    ].each do |path|
      it "has no #{path}" do
        expect(get: path).not_to be_routable
      end
    end

    it 'keeps the extension where something is served in another format' do
      expect(get: '/en/search.json').to route_to('journal#search', locale: 'en', format: 'json')
      expect(get: '/en/feed.atom').to route_to('feeds#feed', locale: 'en', format: 'atom')
      expect(get: '/en/feed').to route_to('feeds#feed', locale: 'en', format: 'atom')
    end

    it 'serves those two in no other format' do
      expect(get: '/en/search.foo').not_to be_routable
      expect(get: '/en/feed.foo').not_to be_routable
    end
  end

  describe 'GET /management/statistics' do
    it 'routes to management/statistics#index without an /index suffix' do
      expect(get: '/management/statistics').to route_to('management/statistics#index')
      expect(get: '/management/statistics/index').not_to be_routable
    end
  end
end
