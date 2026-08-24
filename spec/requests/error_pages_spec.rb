# frozen_string_literal: true

require 'rails_helper'

# config.exceptions_app has pointed at the router since the app was generated, but nothing was
# routed at /404 — so a production 404 fell through to an empty body. These specs run with the
# exception middleware switched on, which is the only way to see what a visitor would get.
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
end
