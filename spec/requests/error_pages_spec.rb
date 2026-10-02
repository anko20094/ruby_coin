# frozen_string_literal: true

require 'rails_helper'

# Run with the exception middleware switched on: it is the only way to see what a visitor gets.
describe 'error pages', type: :request do
  around do |example|
    config = Rails.application.env_config
    was = config.values_at('action_dispatch.show_exceptions', 'action_dispatch.show_detailed_exceptions')

    config['action_dispatch.show_exceptions'] = :all
    # Without this the debug page answers instead of exceptions_app, and the spec would be
    # testing the development error screen rather than what a visitor sees.
    config['action_dispatch.show_detailed_exceptions'] = false

    example.run
  ensure
    config['action_dispatch.show_exceptions'], config['action_dispatch.show_detailed_exceptions'] = was
  end

  it 'renders the designed 404 inside the real layout' do
    get '/en/there-is-nothing-here'

    expect(response).to have_http_status(:not_found)
    expect(response.body).to include('er-page')
    expect(response.body).to include(I18n.t('error_pages.not_found.title', locale: :en))
  end

  it 'keeps the reader on the site — the nav and the footer are still there' do
    get '/en/there-is-nothing-here'

    expect(response.body).to include('rc-nav')
    expect(response.body).to include('rc-footer')
    expect(response.body).to include(work_path(locale: 'en'))
    expect(response.body).to include(journal_path(locale: 'en'))
  end

  it 'answers in the language of the address that failed' do
    get '/uk/there-is-nothing-here'

    expect(response.body).to include(I18n.t('error_pages.not_found.title', locale: :uk))
    expect(response.body).to include('<html lang="uk"')
  end

  it 'falls back to the default locale when the address carries none' do
    get '/there-is-nothing-here'

    expect(response).to have_http_status(:not_found)
    expect(response.body).to include(I18n.t('error_pages.not_found.title', locale: I18n.default_locale))
  end

  it 'answers a missing post with 404 rather than a redirect to the index' do
    get '/en/post/a-slug-that-never-existed'

    expect(response).to have_http_status(:not_found)
    expect(response.body).to include('er-page')
  end

  # Dispatched outside the /:locale scope, so the nav switcher can only offer a query parameter.
  it 'answers in the language the locale switch asks for' do
    get '/404?locale=en'
    expect(response.body).to include('<html lang="en"')

    get '/404?locale=uk'
    expect(response.body).to include('<html lang="uk"')
  end

  it 'ignores a locale it does not have' do
    get '/404?locale=fr'

    expect(response.body).to include(%(<html lang="#{I18n.default_locale}"))
  end

  describe 'a miss on a page that has a record behind it' do
    include_context 'when the cases are imported'

    it 'is a 404 on the designed page for a case that does not exist' do
      get '/en/work/nope'

      expect(response).to have_http_status(:not_found)
      expect(response.body).to include('er-page')
    end

    it 'is a 404 on the designed page for a person who does not exist' do
      get '/en/team/nobody'

      expect(response).to have_http_status(:not_found)
      expect(response.body).to include('er-page')
    end
  end

  describe 'a request that is not for a page' do
    %w[/apple-touch-icon.png /humans.txt /en/missing.json /en/missing.xml /.env /en.foo /en/work.foo].each do |path|
      it "answers #{path} with the designed 404" do
        get path

        expect(response).to have_http_status(:not_found)
        expect(response.media_type).to eq('text/html')
        expect(response.body).to include('er-page')
      end
    end

    it 'answers a missing post asked for as JSON with the designed 404' do
      get '/en/post/a-slug-that-never-existed', headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:not_found)
      expect(response.body).to include('er-page')
    end
  end

  describe 'the 422 page' do
    around do |example|
      was = ActionController::Base.allow_forgery_protection
      ActionController::Base.allow_forgery_protection = true

      example.run
    ensure
      ActionController::Base.allow_forgery_protection = was
    end

    it 'answers a form posted without its token' do
      post '/en/users/sign_in', params: { user: { email: 'someone@example.com', password: 'password' } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('er-page')
      expect(response.body).to include(I18n.t('error_pages.unacceptable.title', locale: :en))
    end
  end

  describe 'the 500 page' do
    include_context 'when the cases are imported'

    it 'is the designed page when an action raises' do
      allow(Case).to receive(:ordered).and_raise(StandardError, 'boom')

      get '/en/work'

      expect(response).to have_http_status(:internal_server_error)
      expect(response.body).to include('er-page')
      expect(response.body).to include(I18n.t('error_pages.internal.title', locale: :en))
    end

    # A database that is down is the commonest reason for a 500 — and when the layout fails
    # again while explaining the first failure, the static page is what is left.
    it 'is the static page when the layout cannot render either' do
      allow(Team).to receive(:owner_cv).and_raise(ActiveRecord::ConnectionNotEstablished)

      get '/en/journal'

      expect(response).to have_http_status(:internal_server_error)
      expect(response.media_type).to eq('text/html')
      expect(response.body.b).to eq(Rails.public_path.join('500.html').binread)
    end
  end

  describe 'a query string that url_for would read as routing' do
    ['/en/nope?controller=x', '/en/nope?action=x', '/en/nope?_recall=x', '/en/nope?host=evil.example'].each do |path|
      it "keeps #{path} on the designed 404, with a switcher that stays on this site" do
        get path

        expect(response).to have_http_status(:not_found)
        hrefs = response.body.scan(/class="rc-nav__locale[^"]*"[^>]*href="([^"]*)"/).flatten
        expect(hrefs).to all(start_with('/404?'))
      end
    end
  end
end
