# frozen_string_literal: true

# The pages behind config.exceptions_app (config/application.rb). That setting has been on
# since the app was generated, but nothing was routed at /404 or /500 — so every production
# 404 fell through to an empty body, and public/404.html was never reached.
#
# Rendered inside the real layout, so a reader who mistypes a URL is still on the site: the
# nav, the footer and the way out are all where they were.
class ErrorsController < ApplicationController
  layout 'theme'

  # Rails rewrites path_info to "/404" before dispatching here and keeps the address the
  # reader actually asked for in this header. It is the only way back to the locale they were
  # browsing in — the /:locale segment is gone by the time this controller runs.
  ORIGINAL_PATH = 'action_dispatch.original_path'

  # One template, three registers. 404 is the one a reader actually sees, so it is the one
  # with the copy; the other two say less because there is less honest to say.
  COPY_KEYS = { 404 => :not_found, 422 => :unacceptable, 500 => :internal }.freeze

  # No CSRF token to verify on a request that already failed, and no session to protect.
  skip_forgery_protection

  def not_found
    render :show, status: :not_found
  end

  def unacceptable
    render :show, status: :unprocessable_content
  end

  def internal_error
    render :show, status: :internal_server_error
  end

  private

  # Errors are dispatched outside the /:locale scope, so switch_locale sees no locale param
  # and would answer every mistyped English URL in Ukrainian.
  def switch_locale(&)
    I18n.with_locale(locale_from_original_path, &)
  end

  def locale_from_original_path
    segment = request.headers[ORIGINAL_PATH].to_s.split('/')[1]
    I18nExtended::AVAILABLE_LOCALES.include?(segment) ? segment : I18n.default_locale
  end

  helper_method :error_status

  def error_status
    response.status
  end
end
