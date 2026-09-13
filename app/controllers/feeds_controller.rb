# frozen_string_literal: true

# The two files a site is expected to have and this one did not: a sitemap, so a crawler is
# told what exists rather than guessing from links, and a feed, so the Ukrainian Rails readers
# the journal was built for can follow it without opening the site.
#
# Both are generated rather than stored — there are tens of URLs, not thousands — and both are
# conditionally cacheable off the newest thing in them, so a crawler that asks twice gets a 304
# the second time.
class FeedsController < ApplicationController
  ENTRIES = 30

  # The sitemap lists both locales of every page, so it lives outside the locale scope and
  # renders the same document whoever asks.
  def sitemap
    @pages = sitemap_pages
    @posts = Post.active.limit(200).to_a
    @cases = Case.ordered.to_a
    @people = Team.people

    return unless stale?(etag: [@posts.map(&:updated_at).max, @cases.map(&:updated_at).max, Team.version],
                         public: true)

    expires_in 1.hour, public: true
    render formats: :xml
  end

  def feed
    @posts = Post.active.includes(:tags, :user, :translations).limit(ENTRIES).to_a
    @updated_at = @posts.filter_map(&:updated_at).max || Time.zone.now

    return unless stale?(etag: [@posts.map(&:updated_at).max, I18n.locale], public: true)

    expires_in 1.hour, public: true
    render formats: :atom
  end

  def robots
    expires_in 1.day, public: true
    render plain: robots_body, content_type: 'text/plain'
  end

  private

  # The static pages, by route name. /search stays out of robots.txt but in here: it is the
  # address the palette points at, and a crawler told not to crawl it still benefits from
  # knowing it exists.
  def sitemap_pages
    %i[root journal work team cv studio contact faq search].map { |name| public_send(:"#{name}_path", locale: nil) }
  end

  def robots_body
    <<~ROBOTS
      # https://www.robotstxt.org/robotstxt.html
      User-agent: *
      Disallow: /management/
      Disallow: /users/
      # The search screen is an unbounded crawl space: every query string is a distinct URL
      # with no content of its own.
      Disallow: /*/search

      Sitemap: #{root_url(locale: nil)}sitemap.xml
    ROBOTS
  end
end
