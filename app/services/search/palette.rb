# frozen_string_literal: true

module Search
  # What ⌘K answers with: the site, in one list.
  #
  # The handoff says to back the palette with the existing /search PgSearch action rather than
  # filtering in memory — the prototype did the latter only because it had no server. So this
  # is that action's other format, widened to cover the two things the palette also has to
  # find: the cases, and the pages themselves.
  class Palette < BaseService
    LIMIT = 8

    Result = Struct.new(:kind, :title, :hint, :url, keyword_init: true) do
      def as_json(*) = { kind: kind, title: title, hint: hint, url: url }
    end

    # Case fields are TinyMCE markup. The palette answers in JSON and the browser prints the
    # result as text, so a bolded word would arrive as a literal <b>.
    def self.plain(value) = ActionController::Base.helpers.strip_tags(value.to_s).strip

    def initialize(query, routes:, locale: I18n.locale)
      @query = query.to_s.strip
      @routes = routes
      @locale = locale
    end

    def call
      return { query: @query, results: [] } if @query.blank?

      { query: @query, results: (pages + cases + posts).first(LIMIT).map(&:as_json) }
    end

    private

    attr_reader :query, :routes, :locale

    # Pages first: someone typing "con" almost always wants /contact, not an article that
    # happens to contain the word.
    def pages
      [
        [I18n.t('work.nav.journal'), routes.journal_path(locale: locale)],
        [I18n.t('work.nav.work'), routes.work_path(locale: locale)],
        [I18n.t('work.nav.contact'), routes.contact_path(locale: locale)],
        [I18n.t('titles.faq'), routes.faq_path(locale: locale)]
      ].filter_map do |title, path|
        next unless title.to_s.downcase.include?(query.downcase)

        Result.new(kind: 'page', title: title, hint: path, url: path)
      end
    end

    def cases
      Case.ordered.select { |kase| matches_case?(kase) }.map do |kase|
        Result.new(kind: 'case', title: self.class.plain(kase.title), hint: self.class.plain(kase.tagline),
                   url: routes.work_case_path(slug: kase.slug, locale: locale))
      end
    end

    def matches_case?(kase)
      needle = query.downcase
      [self.class.plain(kase.title), self.class.plain(kase.tagline), kase.sector, kase.slug]
        .compact.any? { |field| field.downcase.include?(needle) }
    end

    def posts
      Posts::Search.call(query: query, search_in: 'all')
                   .limit(LIMIT)
                   .includes(:translations)
                   .map do |post|
        Result.new(kind: 'entry', title: post.title, hint: post.created_at.strftime('%Y·%m·%d'),
                   url: routes.post_path(post, locale: locale))
      end
    end
  end
end
