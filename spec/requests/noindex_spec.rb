# frozen_string_literal: true

require 'rails_helper'

# robots.txt Disallow is a prefix match on a path a crawler may still list when it is linked to;
# the header is what a crawler that did fetch the page is told.
describe 'keeping the admin and the sign-in screens out of the index', type: :request do
  include_context 'when the cv is imported'

  let(:noindex) { 'noindex, nofollow' }

  I18nExtended::AVAILABLE_LOCALES.each do |locale|
    context "for /#{locale}" do
      it 'marks the sign-in page' do
        get new_user_session_path(locale:)

        expect(response).to be_successful
        expect(response.headers['X-Robots-Tag']).to eq(noindex)
      end

      it 'marks the password reset page' do
        get new_user_password_path(locale:)

        expect(response).to be_successful
        expect(response.headers['X-Robots-Tag']).to eq(noindex)
      end

      it 'marks the closed registration screen, which redirects' do
        get new_user_registration_path(locale:)

        expect(response).to have_http_status(:see_other)
        expect(response.headers['X-Robots-Tag']).to eq(noindex)
      end

      it 'marks the admin to a signed-in staff member' do
        sign_in create(:user, role: :admin)

        get management_root_path(locale:)

        expect(response).to be_successful
        expect(response.headers['X-Robots-Tag']).to eq(noindex)
      end

      it 'marks a screen the admin refuses to a member without the role' do
        sign_in create(:user, role: :user)

        get management_root_path(locale:)

        expect(response.headers['X-Robots-Tag']).to eq(noindex)
      end

      it 'leaves the public pages indexable' do
        get journal_path(locale:)

        expect(response).to be_successful
        expect(response.headers).not_to have_key('X-Robots-Tag')
      end
    end
  end
end
