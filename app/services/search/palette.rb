# frozen_string_literal: true

module Search
  # What ⌘K answers with: the site, in one list.
  #
  # Backed by the same PgSearch as /search rather than filtering in memory, widened to also
  # find the cases and the pages themselves.
  class Palette < BaseService
    LIMIT = 8

    # `kind` stays the machine word the tests and any future styling read; `label` is what the
    # row prints, and it is translated — the badge said PAGE and PERSON on a Ukrainian page.
    Result = Struct.new(:kind, :title, :hint, :url, keyword_init: true) do
      def as_json(*) = { kind: kind, label: I18n.t("global.palette.kinds.#{kind}"), title: title, hint: hint, url: url }
    end

    def initialize(query, routes:, locale: I18n.locale)
      @query = query.to_s.strip
      @routes = routes
      @locale = locale
    end

    def call
      return { query: @query, results: [] } if @query.blank?

      { query: @query, results: (pages + people + cases + posts).first(LIMIT).map(&:as_json) }
    end

    private

    attr_reader :query, :routes, :locale

    # Case fields are TinyMCE markup. The palette answers in JSON and the browser prints the
    # result with textContent, so a bolded word would arrive as a literal <b> — and an escaped
    # ampersand as a literal &amp;, which is what "cofounder · product & clients" did.
    def plain(value) = ProseHelper.plain(value)

    # Pages first: someone typing "con" almost always wants /contact, not an article that
    # happens to contain the word.
    #
    # Matched on the address as well as the title, because the two do not always share a word:
    # the CV page is called "Curriculum vitae", and "cv" is what a reader types — it is what the
    # nav chip and the URL both say.
    # A row is [what the result reads as, other names the site prints for the same page, path].
    # The roster's heading is "Who is here" and the footer calls it "the crew"; in Ukrainian both
    # the footer and the eyebrow call it `команда`, which is the word a reader types.
    def pages
      [
        [I18n.t('work.nav.journal'), [], routes.journal_path(locale: locale)],
        [I18n.t('work.nav.work'), [], routes.work_path(locale: locale)],
        [I18n.t('work.nav.studio'), [], routes.studio_path(locale: locale)],
        [
          I18n.t('team.index.title'), [I18n.t('work.footer.team'), I18n.t('team.index.eyebrow')],
          routes.team_path(locale: locale)
        ],
        [I18n.t('cv.show.title'), [I18n.t('work.nav.cv')], routes.cv_path(locale: locale)],
        [I18n.t('work.nav.contact'), [], routes.contact_path(locale: locale)],
        [I18n.t('titles.faq'), [], routes.faq_path(locale: locale)]
      ].filter_map do |title, aliases, path|
        next unless matches_page?([title, *aliases], path)

        Result.new(kind: 'page', title: title, hint: path, url: path)
      end
    end

    # The address is the other name every page has, and for /cv it is the only one a reader
    # would type — the page is called "Curriculum vitae".
    def matches_page?(names, path)
      needle = query.downcase

      names.any? { |name| name.to_s.downcase.include?(needle) } ||
        path.split('/').last.to_s.downcase.include?(needle)
    end

    # The roster is small enough to filter in memory, and it has to be: it is a YAML file, not
    # a table. The id is matched as well as the name, so "natalia" finds Наталя on a Ukrainian
    # page — the names are translated, the ids are not.
    def people
      Team.people.select { |person| person.page? && matches_person?(person) }.map do |person|
        Result.new(kind: 'person', title: plain(person.name), hint: plain(person.role),
                   url: routes.person_path(person, locale: locale))
      end
    end

    def matches_person?(person)
      needle = query.downcase
      [plain(person.name), plain(person.role), person.id]
        .compact.any? { |field| field.downcase.include?(needle) }
    end

    def cases
      Case.ordered.select { |kase| matches_case?(kase) }.map do |kase|
        Result.new(kind: 'case', title: plain(kase.title), hint: plain(kase.tagline),
                   url: routes.work_case_path(slug: kase.slug, locale: locale))
      end
    end

    def matches_case?(kase)
      needle = query.downcase
      [plain(kase.title), plain(kase.tagline), kase.sector, kase.slug]
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
