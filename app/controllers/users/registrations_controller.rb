# frozen_string_literal: true

module Users
  class RegistrationsController < Devise::RegistrationsController
    before_action :configure_account_update_params, only: [:update]

    protected

    def configure_account_update_params
      devise_parameter_sanitizer.permit(:account_update, keys: [:nickname])
    end
  end
end
