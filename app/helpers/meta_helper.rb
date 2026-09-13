# frozen_string_literal: true

# What a link to this site unfurls into, and what a crawler is told about it.
#
# Before this there was nothing: no description, no Open Graph, no Twitter card, no canonical
# and no hreflang on any page. A case link pasted into Telegram or LinkedIn showed a grey
# rectangle with a URL in it — on a site whose entire purpose is links that get pasted.
#
# A page declares itself with `page_meta` in the view; the layout renders whatever it finds and
# falls back to the site's own card and lede where a page says nothing. The value has to
# survive from the template to the layout, which in Rails means an instance variable on the
# view context — the same thing content_for does, but holding a hash rather than a buffer.
# rubocop:disable Rails/HelperInstanceVariable
module MetaHelper
  SITE_NAME = 'rubyco.in'
  DESCRIPTION_LIMIT = 200

  # `person` names who a profile page is about. Without it every profile page would describe
  # the owner: the schema read CVProfile directly, so /team/natalia would have told a search
  # engine it was Danyil's page.
  def page_meta(description: nil, image: nil, type: 'website', published_at: nil, updated_at: nil, person: nil)
    @page_meta = {
      description: description, image: image, type: type,
      published_at: published_at, updated_at: updated_at, person: person
    }.compact
  end

  # Through ProseHelper#plain rather than strip_tags: what comes back here goes straight into an
  # attribute, which escapes it again. strip_tags alone left the entities in, so a role reading
  # "product & clients" was served to Telegram and Slack as "product &amp;amp; clients".
  def meta_description
    text = @page_meta&.dig(:description).presence || CVProfile.current.summary
    plain(text).squish.truncate(DESCRIPTION_LIMIT, separator: ' ')
  end

  def meta_title
    content_for?(:title) ? plain(content_for(:title)) : SITE_NAME
  end

  def meta_type = @page_meta&.dig(:type) || 'website'

  # An absolute URL, because a share card is fetched by someone else's server.
  def meta_image
    path = @page_meta&.dig(:image).presence || "/og/site-#{I18n.locale}.png"
    path.start_with?('http') ? path : URI.join(request.base_url, path).to_s
  end

  def meta_published_at = @page_meta&.dig(:published_at)
  def meta_updated_at = @page_meta&.dig(:updated_at)

  # The same page in the other language, and the canonical form of this one. The site answers
  # at /en/… and /uk/… only — the locale-less address redirects (I18nExtended) — so the
  # canonical is simply the current path without its query string.
  def canonical_url
    URI.join(request.base_url, request.path).to_s
  end

  def alternate_urls
    I18nExtended::AVAILABLE_LOCALES.index_with do |locale|
      URI.join(request.base_url, url_for(locale: locale, only_path: true)).to_s
    end
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

  def article_schema
    {
      '@context' => 'https://schema.org', '@type' => 'BlogPosting',
      headline: meta_title, description: meta_description, image: meta_image,
      url: canonical_url, inLanguage: I18n.locale.to_s,
      datePublished: meta_published_at&.iso8601, dateModified: meta_updated_at&.iso8601,
      author: { '@type' => 'Person', name: CVProfile.current.name }
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
    profile = CVProfile.current

    {
      name: profile.name, role: profile.role, description: profile.summary,
      links: profile.contact_rows.filter_map { |_, _, href| href unless href.to_s.start_with?('mailto:') }
    }
  end
end
# rubocop:enable Rails/HelperInstanceVariable
