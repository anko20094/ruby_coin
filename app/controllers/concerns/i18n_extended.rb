# frozen_string_literal: true

module I18nExtended
  AVAILABLE_LOCALES = %w[uk en].freeze

  # `*/*` counts as a page load. Rails reports it as its own format rather than as HTML, and
  # it is what most crawlers and every curl send — the ones whose duplicate copy of the site
  # the locale redirect exists to stop.
  ANY_FORMAT = '*/*'

  extend ActiveSupport::Concern

  included do
    around_action :switch_locale
  end

  private

  def switch_locale(&)
    locale = request.path_parameters[:locale]

    return redirect_to_negotiated_locale if locale.blank? && negotiable_request?

    locale = I18n.default_locale unless AVAILABLE_LOCALES.include?(locale.to_s)
    I18n.with_locale(locale, &)
  end

  # The locale segment is optional in the routes, so every page had a second address without
  # one — and that address always answered in Ukrainian, whoever asked. /cv is the URL a
  # printed CV carries, and it sent an English-speaking recruiter to a Ukrainian page whose
  # only way out was a 10px EN in the corner.
  #
  # Now the locale-less address is a redirect rather than a page: it picks a language from the
  # browser and sends the reader there. That also ends the duplicate-content problem — one
  # piece of content, one URL that returns 200.
  #
  # Only for plain page loads: a form post or an XHR keeps working under the default locale
  # rather than being bounced to a URL it did not ask for.
  #
  def negotiable_request?
    return false unless request.get? || request.head?
    return false if request.xhr?

    request.format.html? || request.format.atom? || request.format.to_s == ANY_FORMAT
  end

  def redirect_to_negotiated_locale
    redirect_to "/#{negotiated_locale}#{request.fullpath}", status: :found, allow_other_host: false
  end

  # Deliberately small: match the browser's ordered preferences against the two languages this
  # site has, and fall back to the default. Quality values are honoured because a browser set
  # to "uk, en;q=0.8" means it.
  def negotiated_locale
    accepted_locales.find { |tag| AVAILABLE_LOCALES.include?(tag) } || I18n.default_locale
  end

  def accepted_locales
    request.headers['Accept-Language'].to_s
           .split(',')
           .map { |part| part.split(';') }
           .map { |tag, quality| [tag.to_s.strip.downcase.split('-').first, quality.to_s[/[\d.]+/].to_f] }
           .sort_by { |_, quality| -(quality.zero? ? 1.0 : quality) }
           .map(&:first)
  end

  def default_url_options
    { locale: I18n.locale, **Rails.application.config.x.canonical_url_options }
  end
end
