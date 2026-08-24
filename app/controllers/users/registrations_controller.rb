# frozen_string_literal: true

module Users
  # Registration is closed.
  #
  # This is a portfolio and a journal with one author and an admin behind a password. There is
  # no member area, nothing to sign up for, and no email confirmation — so an open /users/sign_up
  # meant anyone could create an account on it, and did nothing for them if they did. The rest
  # of :registerable stays: an account, once it exists, can still be edited.
  class RegistrationsController < Devise::RegistrationsController
    before_action :registration_is_closed, only: %i[new create]
    before_action :configure_account_update_params, only: [:update]

    protected

    def registration_is_closed
      redirect_to new_user_session_path, alert: t('devise.registrations.closed'), status: :see_other
    end

    def configure_account_update_params
      devise_parameter_sanitizer.permit(:account_update, keys: [:nickname])
    end
  end
end
