# frozen_string_literal: true

require 'rails_helper'

# redesign_plan.md §2 has promised these since the plan was written and nothing was in place:
# sign-in, password reset and the search screen were all unmetered.
describe 'throttling', type: :request do
  around do |example|
    Rack::Attack.enabled = true
    Rack::Attack.cache.store.clear
    example.run
  ensure
    Rack::Attack.enabled = false
    Rack::Attack.cache.store.clear
  end

  def sign_in_attempt(email: 'someone@example.com', ip: '203.0.113.10')
    post user_session_path(locale: 'en'),
         params: { user: { email: email, password: 'wrong-password' } },
         env: { 'REMOTE_ADDR' => ip }
  end

  it 'lets a person mistype their password a few times' do
    3.times { sign_in_attempt }

    expect(response).not_to have_http_status(:too_many_requests)
  end

  it 'stops a script sitting on the sign-in form' do
    11.times { sign_in_attempt }

    expect(response).to have_http_status(:too_many_requests)
  end

  it 'says how long to wait, in a way a person can read' do
    11.times { sign_in_attempt }

    expect(response.headers['retry-after']).to be_present
    expect(response.body).to include('Try again')
  end

  # An attacker rotating IPs against one account is the case the per-IP rule misses.
  it 'counts attempts against one account across addresses' do
    11.times { |n| sign_in_attempt(email: 'victim@example.com', ip: "203.0.113.#{n + 20}") }

    expect(response).to have_http_status(:too_many_requests)
  end

  it 'never meters assets' do
    400.times { get '/assets/theme.css', env: { 'REMOTE_ADDR' => '203.0.113.99' } }

    expect(response).not_to have_http_status(:too_many_requests)
  end
end
