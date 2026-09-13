# frozen_string_literal: true

require 'rails_helper'

# Turbo Drive is off by decision, so every click is a full page load and the browser cache is
# the only thing between a reader on 3G and paying for the whole document again. Nothing was
# using it: Rails' default ETag digests the body, and the body carried a fresh CSRF token on
# every response, so no two responses ever matched.
describe 'HTTP caching', type: :request do
  include_context 'when the cases are imported'
  include_context 'when the cv is imported'

  def etag_for(path)
    get path
    response.headers['ETag']
  end

  it 'answers an unchanged page with 304 and no body' do
    tag = etag_for('/en/work')

    get '/en/work', headers: { 'If-None-Match' => tag }

    expect(response).to have_http_status(:not_modified)
    expect(response.body).to be_empty
  end

  it 'lets a shared cache hold the pages that change a few times a year' do
    %w[/en/work /en/work/dna /en/contact /en/faq].each do |path|
      get path

      expect(response.headers['Cache-Control']).to include('public'), "#{path} is not publicly cacheable"
    end
  end

  it 'stops being fresh when the content changes' do
    before_edit = etag_for('/en/work/dna')

    Case.find_by!(slug: 'dna').update!(year: { 'en' => '2099', 'uk' => '2099' })

    get '/en/work/dna', headers: { 'If-None-Match' => before_edit }

    expect(response).to have_http_status(:success)
  end

  it 'gives the two locales different entity tags for the same case' do
    expect(etag_for('/en/work/dna')).not_to eq(etag_for('/uk/work/dna'))
  end

  it 'never hands a page carrying a message to a shared cache' do
    get '/en/post/a-slug-that-never-existed'

    get '/en/work', headers: { 'If-None-Match' => etag_for('/en/work') }
    expect(response).to have_http_status(:not_modified)
  end

  # Removing csrf_meta_tags from the theme layout is what makes the rest of the site
  # conditionally cacheable too, so this pins the reason it is gone.
  it 'keeps the theme layout free of the per-response CSRF token' do
    get '/en/journal'

    expect(response.body).not_to include('name="csrf-token"')
  end

  it 'still gives the admin its CSRF token' do
    # The test environment turns forgery protection off, so csrf_meta_tags renders nothing
    # anywhere; switch it on for this one example or it would pass whatever the layouts say.
    was = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    sign_in create(:user, role: :admin)

    get '/en/management/posts'

    expect(response.body).to include('name="csrf-token"')
  ensure
    ActionController::Base.allow_forgery_protection = was
  end
end
