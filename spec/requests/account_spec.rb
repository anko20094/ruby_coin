# frozen_string_literal: true

require 'rails_helper'

# Devise's destroy asks for no password, so the route went with the button.
describe 'the one account', :jobs, type: :request do
  let!(:admin) { create(:user, :admin, password: 'password123') }
  let!(:entry) { create(:post, user: admin) }

  describe 'DELETE /users' do
    before { sign_in admin }

    it 'is not a route' do
      expect { Rails.application.routes.recognize_path('/en/users', method: :delete) }
        .to raise_error(ActionController::RoutingError)
    end

    it 'deletes neither the account nor the journal' do
      expect { delete '/en/users' }.not_to(change { [User.count, Post.count] })
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'what an existing account can still do' do
    it 'opens its edit form' do
      sign_in admin

      get edit_user_registration_path(locale: 'en')

      expect(response).to be_successful
    end

    it 'changes its nickname' do
      sign_in admin

      patch user_registration_path(locale: 'en'),
            params: { user: { nickname: 'renamed', current_password: 'password123' } }

      expect(admin.reload.nickname).to eq('renamed')
    end

    it 'signs in' do
      post user_session_path(locale: 'en'), params: { user: { email: admin.email, password: 'password123' } }

      expect(response).to be_redirect
      get management_root_path(locale: 'en')
      expect(response).to be_successful
    end

    it 'asks for a password reset, and the mail goes out' do
      asking = lambda do
        post user_password_path(locale: 'en'), params: { user: { email: admin.email } }
        perform_enqueued_jobs
      end

      expect(&asking).to change { ActionMailer::Base.deliveries.size }.by(1)
    end
  end

  describe 'registration' do
    include_context 'when errors render as pages'

    it 'stays closed: the sign-up address sends you home' do
      get '/en/users/sign_up'

      expect(response).to redirect_to('/en')
    end

    it 'sends a locale-less sign-up address to the default locale' do
      get '/users/sign_up'

      expect(response).to redirect_to("/#{I18n.default_locale}")
    end

    it 'cannot be posted to' do
      attempt = -> { post '/en/users', params: { user: { email: 'a@example.com' } } }

      expect(&attempt).not_to change(User, :count)
      expect(response).to have_http_status(:not_found)
    end
  end
end
