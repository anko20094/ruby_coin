# frozen_string_literal: true

require 'rails_helper'

# /work doubles as the CV, so /cv is gone for good. /studio is the one nav section still
# waiting to be built — it needs real team data.
RSpec.describe 'Work redirects' do
  it 'sends /cv to /work permanently' do
    get '/cv'

    expect(response).to have_http_status(:moved_permanently)
    expect(response).to redirect_to('/work')
  end

  it 'keeps the locale when redirecting /cv' do
    get '/uk/cv'

    expect(response).to redirect_to('/uk/work')
  end

  # 302, not 301: /studio is coming, and a permanent redirect would still be cached in
  # browsers and search engines on the day it lands. `redirect` defaults to 301, so this is
  # the assertion that keeps the default from creeping back.
  it 'sends /studio to /work temporarily' do
    get '/en/studio'

    expect(response).to have_http_status(:found)
    expect(response).to redirect_to('/en/work')
  end
end
