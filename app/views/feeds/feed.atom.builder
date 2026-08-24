# frozen_string_literal: true

# The journal as an Atom feed. The site's original audience reads Ukrainian Rails lessons; a
# feed is how people follow that without checking a page.
xml.instruct!
xml.feed(xmlns: 'http://www.w3.org/2005/Atom', 'xml:lang' => I18n.locale.to_s) do
  xml.title "#{t('journal.index.title')} · #{MetaHelper::SITE_NAME}"
  xml.subtitle t('journal.index.lede')
  xml.id journal_url
  xml.link rel: 'self', href: feed_url(format: :atom)
  xml.link rel: 'alternate', type: 'text/html', href: journal_url
  xml.updated @updated_at.iso8601
  xml.author { xml.name CVProfile.current.name }

  @posts.each do |post|
    xml.entry do
      xml.id post_url(post)
      xml.title post.title
      xml.link rel: 'alternate', type: 'text/html', href: post_url(post)
      xml.published post.created_at.iso8601
      xml.updated post.updated_at.iso8601
      xml.summary post.subtitle
      xml.content post.plain_body.truncate(1200, separator: ' '), type: 'text'
      post.tags.each { |tag| xml.category term: tag.title }
    end
  end
end
