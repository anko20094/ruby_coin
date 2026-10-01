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
  PAGE_TTL = 5.minutes

  # Rails only digests the action's own template, and for Slim not even its partials.
  RELEASE_SOURCES = '{app,config/locales,public/og}/**/*'

  included do
    etag { HttpCaching.release }
  end

  class << self
    # Everything a page is rendered from besides its records, so a deploy that touches any of
    # it expires what browsers hold. Development re-reads it, because there the files are what
    # is being edited.
    def release
      return digest_sources if Rails.application.config.enable_reloading

      @release ||= digest_sources
    end

    private

    def digest_sources
      files = Rails.root.glob(RELEASE_SOURCES).select(&:file?).sort << Rails.root.join('Gemfile.lock')

      Digest::SHA256.hexdigest(files.sum('') { |path| Digest::SHA256.file(path).hexdigest })
    end
  end

  private

  # `page` is whatever the page is made of — records, arrays of them, anything with a cache
  # key — and nothing for a page made of what every page shares. That part is added here, so a
  # new page cannot forget it: the footer's CV, the language, and the day (the copyright year
  # and the draft chip read the clock).
  #
  # Browser cache only: every response sets the visitor's Ahoy cookie, which a shared cache
  # must never replay to the next reader.
  def cache_publicly(*page)
    return false if uncacheable?

    expires_in PAGE_TTL
    fresh_when(etag: [page, CVProfile.current, I18n.locale, request.path, Date.current])
  end

  # A message meant for this reader must not be answered with a copy of the page from before
  # it.
  def uncacheable?
    flash.any?
  end
end
