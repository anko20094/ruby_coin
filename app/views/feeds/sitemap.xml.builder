# frozen_string_literal: true

# Both locales of every public URL, with the alternates cross-linked so a crawler knows the
# two are the same page rather than duplicate content.
locales = I18nExtended::AVAILABLE_LOCALES

xml.instruct! :xml, version: '1.0'
xml.urlset(xmlns: 'http://www.sitemaps.org/schemas/sitemap/0.9',
           'xmlns:xhtml' => 'http://www.w3.org/1999/xhtml') do
  entries = @pages.map { |path| [path, nil] } +
            @posts.map { |post| [post_path(post, locale: nil), post.updated_at] } +
            @cases.map { |kase| [work_case_path(slug: kase.slug, locale: nil), kase.updated_at] }

  # root_path is "/", which would spell the home page "/uk/" while its own canonical says
  # "/uk". A sitemap that disagrees with the canonical is worse than no sitemap.
  url_for_locale = ->(locale, path) { URI.join(request.base_url, "/#{locale}#{path}".chomp('/')).to_s }

  entries.each do |path, changed_at|
    locales.each do |locale|
      xml.url do
        xml.loc url_for_locale.call(locale, path)
        xml.lastmod changed_at.iso8601 if changed_at
        locales.each do |alternate|
          xml.xhtml :link, rel: 'alternate', hreflang: alternate,
                           href: url_for_locale.call(alternate, path)
        end
      end
    end
  end
end
