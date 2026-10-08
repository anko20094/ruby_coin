# frozen_string_literal: true

require 'rails_helper'

# The locale segment is optional in the routes, so every page also answered at an address
# without one — always in Ukrainian, whoever asked. That is the URL /cv redirects to and the
# one a printed CV carries, so an English-speaking recruiter landed on a Ukrainian page.
describe 'locale negotiation', type: :request do
  include_context 'when the cases are imported'

  it 'sends a browser that prefers English to the English page' do
    get '/work', headers: { 'Accept-Language' => 'en-GB,en;q=0.9' }

    expect(response).to redirect_to('/en/work')
  end

  it 'sends a browser that prefers Ukrainian to the Ukrainian page' do
    get '/work', headers: { 'Accept-Language' => 'uk,en-US;q=0.8' }

    expect(response).to redirect_to('/uk/work')
  end

  it 'honours quality values rather than header order' do
    get '/work', headers: { 'Accept-Language' => 'uk;q=0.3,en;q=0.9' }

    expect(response).to redirect_to('/en/work')
  end

  # q=0 is "not acceptable", not "no preference given".
  it 'does not pick a language the browser marked q=0' do
    get '/work', headers: { 'Accept-Language' => 'en;q=0, uk;q=0.5' }

    expect(response).to redirect_to('/uk/work')
  end

  it 'counts a language with no q as the most wanted' do
    get '/work', headers: { 'Accept-Language' => 'uk;q=0.9, en' }

    expect(response).to redirect_to('/en/work')
  end

  it 'keeps the order of languages the browser weighed the same' do
    get '/work', headers: { 'Accept-Language' => 'de, en;q=0.5, uk;q=0.5' }

    expect(response).to redirect_to('/en/work')
  end

  it 'falls back to the default locale for a language the site does not have' do
    get '/work', headers: { 'Accept-Language' => 'de-DE,de;q=0.9' }

    expect(response).to redirect_to("/#{I18n.default_locale}/work")
  end

  it 'falls back to the default locale when the browser says nothing' do
    get '/work'

    expect(response).to redirect_to("/#{I18n.default_locale}/work")
  end

  it 'carries the query string across' do
    get '/journal?tag_id=3&order=best', headers: { 'Accept-Language' => 'en' }

    expect(response).to redirect_to('/en/journal?tag_id=3&order=best')
  end

  it 'leaves a page that already names its locale alone' do
    get '/en/work'

    expect(response).to have_http_status(:success)
  end

  # One piece of content, one URL that returns 200 — which is also what ends the duplicate
  # content a crawler used to find at /work and /uk/work.
  it 'no longer serves the same page at two addresses' do
    get '/work'
    expect(response).to have_http_status(:found)

    get '/uk/work'
    expect(response).to have_http_status(:success)
  end

  # /cv is the address a printed CV carries, and it used to answer in Ukrainian whoever asked.
  # It is a page of its own now rather than a redirect to /work, but the negotiation is the
  # same: the locale-less address picks a language and sends the reader there.
  it 'takes an English reader from /cv to the English CV' do
    get '/cv', headers: { 'Accept-Language' => 'en' }

    expect(response).to have_http_status(:found)
    expect(response).to redirect_to('/en/cv')
  end

  it 'takes a Ukrainian reader from /cv to the Ukrainian one' do
    get '/cv', headers: { 'Accept-Language' => 'uk,en;q=0.8' }

    expect(response).to redirect_to('/uk/cv')
  end

  # The language is in the path. A ?locale= on an address without one used to be believed, which
  # made /work?locale=en a second 200 for a page that has exactly one.
  it 'does not let a query string stand in for the locale in the path' do
    get '/work?locale=en', headers: { 'Accept-Language' => 'uk' }

    expect(response).to redirect_to('/uk/work?locale=en')
  end

  it 'answers in the language of the path, whatever the query string asks for' do
    get '/uk/work?locale=en'

    expect(response.body).to include('<html lang="uk"')
  end

  it 'sends a feed reader that came without a language to the feed in one' do
    get '/feed', headers: { 'Accept-Language' => 'en' }

    expect(response).to redirect_to('/en/feed')
  end

  it 'leaves the sitemap, which has no language, alone' do
    get '/sitemap.xml'

    expect(response).to have_http_status(:success)
  end
end
