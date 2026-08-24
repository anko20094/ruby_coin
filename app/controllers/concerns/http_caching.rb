# frozen_string_literal: true

# Conditional GETs for the pages that barely change.
#
# Turbo Drive is off on this site by decision, so every click is a full page load. That makes
# the browser cache the only thing standing between a reader on a 3G connection and paying for
# the whole document again on every navigation — and nothing was using it: Rails' default ETag
# is a digest of the body, and the body carried a fresh CSRF token on every response, so no
# two responses ever matched and no 304 was ever possible.
module HttpCaching
  extend ActiveSupport::Concern

  # Long enough that a reader clicking through /work and back does not re-ask, short enough
  # that publishing something is visible without anyone clearing anything.
  PUBLIC_TTL = 5.minutes

  private

  # `record` is whatever the page is made of — a record, an array of them, anything with a
  # cache key. The locale is part of the key because the same records render as two pages.
  def cache_publicly(record, last_modified: nil)
    return false if uncacheable?

    expires_in PUBLIC_TTL, public: true
    fresh_when(etag: [record, I18n.locale, request.path], last_modified: last_modified, public: true)
  end

  # A message meant for this reader must not be answered with a copy of the page from before
  # it, and must never be handed to a shared cache.
  def uncacheable?
    flash.any? || request.format.json?
  end
end
