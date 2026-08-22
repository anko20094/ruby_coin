# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include I18nExtended
  include Pundit::Authorization
  include Pagy::Method

  protect_from_forgery with: :exception
  before_action :set_pagy_locale

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  def set_pagy_locale
    # Pagy 43 internal i18n is thread-local; keep it in sync with Rails I18n
    Pagy::I18n.locale = I18n.locale.to_s
  end

  def user_not_authorized(error_message = nil)
    flash[:alert] = error_message&.message || t('application_controller.alert')
    redirect_to(root_path)
  end
end
