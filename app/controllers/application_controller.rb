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
  before_action :forbid_indexing, if: :devise_controller?

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
  rescue_from Pagy::RangeError, with: :redirect_to_last_page

  private

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

  # A page past the last one has no entries, so it goes to the last page that has. Reached only
  # by a list that passes `raise_range_error: true`.
  def redirect_to_last_page(error)
    redirect_to "#{request.path}?#{request.query_parameters.merge(page: error.pagy.last).to_query}"
  end

  # robots.txt Disallow stops a fetch, not a listing of a linked URL; this is what keeps it out.
  def forbid_indexing
    response.set_header('X-Robots-Tag', 'noindex, nofollow')
  end
end
