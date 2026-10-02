# frozen_string_literal: true

# The pages behind config.exceptions_app (config/application.rb). That setting has been on
# since the app was generated, but nothing was routed at /404 or /500 — so every production
# 404 fell through to an empty body, and public/404.html was never reached.
#
# Rendered inside the real layout, so a reader who mistypes a URL is still on the site: the
# nav, the footer and the way out are all where they were.
class ErrorsController < ApplicationController
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
    render_page :not_found
  end

  def unacceptable
    render_page :unprocessable_content
  end

  def internal_error
    render_page :internal_server_error
  end

  private

  # HTML whatever the request asked for: there is no template in any other format, and looking
  # for one ends in a failsafe 500. When the page itself cannot render — the database is usually
  # what failed — the static one stands in.
  def render_page(status)
    render :show, status: status, formats: :html
  rescue StandardError => e
    Rails.error.report(e, handled: true)
    send_file Rails.public_path.join('500.html'), status: :internal_server_error, type: 'text/html',
                                                  disposition: 'inline'
  end

  # Errors are dispatched outside the /:locale scope, so switch_locale sees no locale param
  # and would answer every mistyped English URL in Ukrainian.
  def switch_locale(&)
    I18n.with_locale(locale_from_original_path, &)
  end

  # The address the reader asked for is the first answer, and an explicit ?locale= is the
  # second: these pages are dispatched outside the /:locale scope, so the switcher in the nav
  # can only offer a query parameter — and without this it offered one that did nothing.
  def locale_from_original_path
    asked = params.permit(:locale)[:locale]
    return asked if I18nExtended::AVAILABLE_LOCALES.include?(asked)

    segment = request.headers[ORIGINAL_PATH].to_s.split('/')[1]
    I18nExtended::AVAILABLE_LOCALES.include?(segment) ? segment : I18n.default_locale
  end

  helper_method :error_status

  def error_status
    response.status
  end
end
