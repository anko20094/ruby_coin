# frozen_string_literal: true

# Both locales of every public URL, with the alternates cross-linked so a crawler knows the
# two are the same page rather than duplicate content.
locales = I18nExtended::AVAILABLE_LOCALES

xml.instruct! :xml, version: '1.0'
xml.urlset(xmlns: 'http://www.sitemaps.org/schemas/sitemap/0.9',
           'xmlns:xhtml' => 'http://www.w3.org/1999/xhtml') do
  # A post is only an address in the languages it has text in, and says so to its alternates.
  entries = @pages.map { |path| [path, nil, locales] } +
            @posts.map { |post| [post_path(post, locale: nil), post.updated_at, @post_locales.fetch(post.id) { [] }] } +
            @cases.map { |kase| [work_case_path(slug: kase.slug, locale: nil), kase.updated_at, locales] } +
            @people.map { |person| [person_path(person, locale: nil), nil, locales] }

  # root_path is "/", which would spell the home page "/uk/" while its own canonical says
  # "/uk". A sitemap that disagrees with the canonical is worse than no sitemap.
  url_for_locale = ->(locale, path) { URI.join(root_url(locale: nil), "/#{locale}#{path}".chomp('/')).to_s }

  entries.each do |path, changed_at, available|
    available.each do |locale|
      xml.url do
        xml.loc url_for_locale.call(locale, path)
        xml.lastmod changed_at.iso8601 if changed_at
        available.each do |alternate|
          xml.xhtml :link, rel: 'alternate', hreflang: alternate,
                           href: url_for_locale.call(alternate, path)
        end
      end
    end
  end
end
