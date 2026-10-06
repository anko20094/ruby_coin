# frozen_string_literal: true

module MetaHelper
  SITE_NAME = 'rubyco.in'
  DESCRIPTION_LIMIT = 160

  # rubocop:disable Rails/HelperInstanceVariable
  # `person` names who a profile page is about. Without it every profile page would describe
  # the owner: the schema read the owner's CV directly, so /team/natalia would have told a search
  # engine it was Danyil's page.
  #
  # `locales` is the languages a page exists in, when that is fewer than all of them (an entry
  # written in one); `canonical_query` the parameters that choose which list a page is.
  def page_meta(description: nil, image: nil, type: 'website', published_at: nil, updated_at: nil, person: nil,
                locales: nil, canonical_query: nil)
    @page_meta = {
      description: description, image: image, type: type,
      published_at: published_at, updated_at: updated_at, person: person,
      locales: locales, canonical_query: canonical_query
    }.compact
  end

  # Through ProseHelper#plain rather than strip_tags: what comes back here goes straight into an
  # attribute, which escapes it again. strip_tags alone left the entities in, so a role reading
  # "product & clients" was served to Telegram and Slack as "product &amp;amp; clients".
  def meta_description
    text = @page_meta&.dig(:description).presence || Team.owner_cv.summary
    plain(text).squish.truncate(DESCRIPTION_LIMIT, separator: ' ')
  end

  def meta_title
    content_for?(:title) ? plain(content_for(:title)) : SITE_NAME
  end

  def meta_type = @page_meta&.dig(:type) || 'website'

  # An absolute URL, because a share card is fetched by someone else's server.
  def meta_image
    path = @page_meta&.dig(:image).presence || "/og/site-#{I18n.locale}.png"
    path.start_with?('http') ? path : absolute_url(path, card_version(path))
  end

  # Cards are baked by `rake og:cards`, so a case added in the admin has none until that runs;
  # nil lets the page fall back to the site's own card instead of pointing at a 404.
  def share_card(slug)
    card = "og/#{slug}-#{I18n.locale}.png"
    "/#{card}" if Rails.public_path.join(card).exist?
  end

  def meta_published_at = @page_meta&.dig(:published_at)
  def meta_updated_at = @page_meta&.dig(:updated_at)

  # The same page in the other language, and the canonical form of this one. The site answers
  # at /en/… and /uk/… only — the locale-less address redirects (I18nExtended) — so the
  # canonical is the current path and the few parameters that choose which list this is.
  def canonical_url
    absolute_url(request.path, canonical_query)
  end

  def alternate_urls
    page_locales.index_with do |locale|
      absolute_url(url_for(locale: locale, only_path: true), canonical_query)
    end
  end

  # The languages this page exists in: all of them unless the page said otherwise, and the
  # language being read is always listed.
  def page_locales
    written = @page_meta&.dig(:locales)
    return I18nExtended::AVAILABLE_LOCALES if written.nil?

    written = written.map(&:to_s) | [I18n.locale.to_s]
    I18nExtended::AVAILABLE_LOCALES.select { |locale| written.include?(locale) }
  end

  # The parameters that make a list a different list: a later page, a tag. A first page and a
  # tag that does not exist are not addresses of their own.
  #
  # Nor is a combination of tags: there are as many of them as there are subsets, each a thin
  # slice of the single-tag lists, so they all name the unfiltered journal as their original
  # rather than each competing to be indexed.
  def listing_query(tag: nil, tags: nil)
    tags = Array(tags || tag)
    return {} if tags.many?

    page = request.query_parameters['page'].to_s.to_i
    { 'page' => (page if page > 1), 'tag_id' => tags.first&.id }.compact
  end

  # Schema.org, so a search engine can tell a person from an article from a portfolio.
  def structured_data
    data =
      case meta_type
      when 'article' then article_schema
      when 'profile' then profile_schema
      end

    return if data.nil?

    tag.script(safe_join([data.to_json.html_safe]), type: 'application/ld+json') # rubocop:disable Rails/OutputSafety
  end

  private

  # From the configured host where there is one, never from the Host the client sent.
  def absolute_url(path, query = {})
    url = URI.join(root_url(locale: nil), path)
    url.query = query.to_query.presence
    url.to_s
  end

  def canonical_query = @page_meta&.dig(:canonical_query) || {}

  # A re-rendered card keeps its file name, and the services that unfurl a link cache the image
  # by URL; the card's recorded digest makes the new one a new address.
  def card_version(path)
    name = path[%r{\A/og/([\w-]+)\.png\z}, 1]
    digest = OgCards.recorded[name] if name

    digest ? { 'v' => digest } : {}
  end

  def article_schema
    {
      '@context' => 'https://schema.org', '@type' => 'BlogPosting',
      headline: meta_title, description: meta_description, image: meta_image,
      url: canonical_url, inLanguage: I18n.locale.to_s,
      datePublished: meta_published_at&.iso8601, dateModified: meta_updated_at&.iso8601,
      author: { '@type' => 'Person', name: Team.owner_cv.name }
    }.compact
  end

  def profile_schema
    subject = @page_meta&.dig(:person) || owner_subject

    {
      '@context' => 'https://schema.org', '@type' => 'ProfilePage',
      url: canonical_url, inLanguage: I18n.locale.to_s,
      mainEntity: {
        '@type' => 'Person', name: subject[:name], jobTitle: subject[:role],
        description: plain(subject[:description]).squish,
        url: canonical_url, sameAs: Array(subject[:links]).presence
      }.compact
    }
  end

  # /cv is the owner's page, so it describes the CV itself.
  def owner_subject
    profile = Team.owner_cv

    { name: profile.name, role: profile.role, description: profile.summary, links: Team.owner&.public_links }
  end
  # rubocop:enable Rails/HelperInstanceVariable
end
