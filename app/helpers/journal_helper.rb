# frozen_string_literal: true

module JournalHelper
  # The rendered body, with code blocks highlighted server-side.
  def journal_body(post, locale = I18n.locale)
    fragment = Nokogiri::HTML5.fragment(post.rich_body(locale).to_s)
    fragment.css('pre').each { |node| highlight_code_block(node) }
    fragment.to_html.html_safe # rubocop:disable Rails/OutputSafety -- Action Text sanitises on save
  end

  def journal_byline(post)
    parts = [post.user&.nickname, t('journal.minutes', count: post.reading_minutes)]
    parts << post.tags.map { |tag| "##{tag.title}" }.join(' ') if post.tags.any?
    parts.compact_blank.join(' · ')
  end

  # Filter chips are plain links — with Turbo Drive off deliberately, an <a> per tag is both
  # correct and the cheapest thing that can work.
  def journal_chip_class(active:)
    ['rc-chip', 'rc-chip--filter', ('is-active' if active)].compact.join(' ')
  end

  private

  # Highlighting happens here, once, server-side — the public page, the admin preview and the
  # mobile view all read the same markup, and no syntax highlighter ships to the browser.
  # Anything Rouge does not have a lexer for stays plain rather than being guessed at.
  def highlight_code_block(node)
    code = node.at_css('code') || node
    language = code['class'].to_s[/language-([\w+-]+)/, 1]
    lexer = language && Rouge::Lexer.find(language)
    return if lexer.nil?

    formatter = Rouge::Formatters::HTML.new
    node.replace(<<~HTML)
      <div class="jn-code">
        <span class="jn-code__lang">#{ERB::Util.html_escape(lexer.tag)}</span>
        <pre class="jn-code__body"><code>#{formatter.format(lexer.new.lex(code.text))}</code></pre>
      </div>
    HTML
  end
end
