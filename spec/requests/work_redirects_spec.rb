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

  it 'sends /studio to /work' do
    get '/en/studio'

    expect(response).to redirect_to('/en/work')
  end
end
