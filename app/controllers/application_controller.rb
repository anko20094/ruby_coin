# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include I18nExtended
  include HttpCaching
  include Pundit::Authorization
  include Pagy::Method

  # The redesign is the site. The old Bootstrap layout survives only inside /management, whose
  # own controller names it; anything that does not choose gets the theme.
  layout 'theme'

  protect_from_forgery with: :exception
  before_action :set_pagy_locale

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  def set_pagy_locale
    # Pagy 43 internal i18n is thread-local; keep it in sync with Rails I18n
    Pagy::I18n.locale = I18n.locale.to_s
  end

  # Pundit's own message names the policy class and the query — "not allowed to
  # Management::PostPolicy#index? this Symbol". It went straight into the flash, so the
  # translated string below was unreachable and the reader saw Ruby. The exception belongs in
  # the log, not on the page.
  def user_not_authorized(error = nil)
    Rails.logger.info { "Pundit denied: #{error.message}" } if error
    flash[:alert] = t('application_controller.alert')
    redirect_to(root_path)
  end
end
