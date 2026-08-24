# frozen_string_literal: true

require 'rails_helper'

# The Devise screens were the last public pages on the old Bootstrap layout — which meant a
# second stylesheet, a second bundle, and a second footer carrying a different Telegram handle,
# a different copyright holder and a dead YouTube link.
describe 'the way in', type: :request do
  include_context 'when the cv is imported'

  describe 'GET /users/sign_in' do
    before { get new_user_session_path(locale: 'en') }

    it 'is on the site, not on a second one' do
      expect(response).to be_successful
      expect(response.body).to include('rc-nav')
      expect(response.body).to include('au-page')
    end

    it 'carries the identity the rest of the site carries' do
      expect(response.body).to include(I18n.with_locale(:en) { CVProfile.current.name })
      expect(response.body).not_to include('t.me/ruby4you')
      expect(response.body).not_to include('javascript:void(0)')
    end

    it 'loads the theme and nothing built for the admin' do
      expect(response.body).to match(%r{/assets/theme[-\w]*\.css})
      expect(response.body).not_to include('application.css')
      expect(response.body).not_to match(%r{/assets/admin[-\w]*\.js})
    end
  end

  # There is no member area and no email confirmation, so an open sign-up meant anyone could
  # create an account and gain nothing by it.
  describe 'registration' do
    it 'is closed' do
      get new_user_registration_path(locale: 'en')

      expect(response).to redirect_to(new_user_session_path)
      expect(flash[:alert]).to be_present
    end

    it 'cannot be posted to either' do
      attempt = lambda do
        post user_registration_path(locale: 'en'),
             params: { user: { email: 'stranger@example.com', password: 'password123' } }
      end

      expect(&attempt).not_to change(User, :count)
    end

    it 'is not offered anywhere' do
      get new_user_session_path(locale: 'en')

      expect(response.body).not_to include(new_user_registration_path(locale: 'en'))
    end
  end

  it 'still lets an account that exists sign in' do
    user = create(:user, role: :admin, password: 'password123')

    post user_session_path(locale: 'en'), params: { user: { email: user.email, password: 'password123' } }

    expect(response).to be_redirect
    follow_redirect!
    expect(response).to be_successful
  end
end
