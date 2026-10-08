# frozen_string_literal: true

module HttpCaching
  extend ActiveSupport::Concern

  # Rails only digests the action's own template, and for Slim not even its partials.
  RELEASE_SOURCES = '{app,config/locales,public/og}/**/*'
  # Capistrano writes the deployed commit here; it names the release without reading app/**.
  REVISION = Rails.root.join('REVISION')

  included do
    etag { HttpCaching.release }
  end

  class << self
    # Everything a page is rendered from besides its records, so a deploy that touches any of
    # it expires what browsers hold. A deployed release is named by its commit, and only a
    # checkout without one hashes the sources. Development asks on every request, because there
    # the files are what is being edited — so it only stats them: the newest mtime and the count
    # (a deleted file moves that) instead of hashing a few megabytes per page.
    def release
      return stamp_sources if Rails.application.config.enable_reloading

      @release ||= revision || digest_sources
    end

    private

    def revision = (REVISION.read.strip.presence if REVISION.file?)

    def source_files = Rails.root.glob(RELEASE_SOURCES).select(&:file?).sort << Rails.root.join('Gemfile.lock')

    def digest_sources
      Digest::SHA256.hexdigest(source_files.sum('') { |path| Digest::SHA256.file(path).hexdigest })
    end

    def stamp_sources
      files = source_files
      "#{files.size}-#{files.map { |path| path.mtime.to_r }.max}"
    end
  end

  private

  # `page` is whatever the page is made of — records, arrays of them, anything with a cache
  # key — and nothing for a page made of what every page shares. That part is added here, so a
  # new page cannot forget it: the roster files and the CV the footer prints (Team.version), the
  # language, and the day (the copyright year and the draft chip read the clock).
  #
  # Browser cache only: every response sets the visitor's Ahoy cookie, which a shared cache
  # must never replay to the next reader.
  #
  # Always revalidated (max-age=0, must-revalidate): the browser keeps the copy but asks first,
  # and gets a bodiless 304 while nothing changed. A positive max-age let it answer the page
  # itself — the redirect after signing out or after a refused action landed on a cached copy
  # with no message, and the message turned up on some later page instead.
  def cache_publicly(*page)
    return false if uncacheable?

    expires_in 0, must_revalidate: true
    fresh_when(etag: [page, Team.version, I18n.locale, request.path, Date.current])
  end

  # A message meant for this reader must not be answered with a copy of the page from before
  # it.
  def uncacheable?
    flash.any?
  end
end
