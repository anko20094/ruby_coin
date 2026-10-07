# frozen_string_literal: true

module JournalHelper
  # The editor's code-sample list is Prism's, and Prism calls HTML "markup".
  LEXER_ALIASES = { 'markup' => 'html' }.freeze
  # The file store is kept across releases and only drops an entry when it is read past its
  # expiry, so every entry gets one: a body nobody opens for a week goes, instead of staying on
  # disk for good.
  BODY_TTL = 1.week

  # The rendered body, with code blocks highlighted server-side. Cached on the rich text row,
  # which moves on every edit, and on the release (HttpCaching.release), which moves on every
  # deploy — the highlighting and the embed markup are code, and a hand-bumped version number
  # was one more thing to forget. Rouge over every listing is the costly part of the page.
  def journal_body(post, locale = I18n.locale)
    rich_text = post.rich_body(locale)
    return render_journal_body(rich_text) unless rich_text.persisted?

    key = ['journal_body', HttpCaching.release, I18n.locale, rich_text]
    Rails.cache.fetch(key, expires_in: BODY_TTL) { render_journal_body(rich_text).to_str }
         .html_safe # rubocop:disable Rails/OutputSafety -- our own render, cached as a string
  end

  # Used by the code block partial, and by the plain <pre> pass below, so a listing looks the
  # same however it got into the body.
  def journal_highlight(source, language)
    lexer = lexer_named(language)
    return ERB::Util.html_escape(source) unless lexer

    Rouge::Formatters::HTML.new.format(lexer.new.lex(source)).html_safe # rubocop:disable Rails/OutputSafety -- Rouge escapes its input
  end

  # `tags: false` where the page draws them as chips of their own — the home page's latest
  # entry did both, and printed the same three tags twice ten pixels apart.
  def journal_byline(post, tags: true)
    parts = [post.user&.nickname, t('journal.minutes', count: post.reading_minutes)]
    parts << post.tags.map { |tag| "##{tag.title}" }.join(' ') if tags && post.tags.any?
    parts.compact_blank.join(' · ')
  end

  # Filter chips are plain links — with Turbo Drive off deliberately, an <a> per tag is both
  # correct and the cheapest thing that can work.
  def journal_chip_class(active:)
    ['rc-chip', 'rc-chip--filter', ('is-active' if active)].compact.join(' ')
  end

  # The chosen chip was filled in ink and said nothing else, so which filter is on was a fact
  # only a sighted reader had. `true` rather than `page`: these are items in a set, and the
  # address they point at is the page the reader is already on.
  def journal_chip_attributes(active:)
    { class: journal_chip_class(active: active), aria: { current: ('true' if active) } }
  end

  # The tag_id a link carries: one tag stays the scalar ?tag_id=3 every older link used, so a
  # single-tag list keeps its one address; two or more go as a sorted array.
  def journal_tags_param(tags)
    ids = tags.map(&:id).sort
    ids.one? ? ids.first : ids.presence
  end

  # Where a chip goes: the list with its tag switched on or off, the rest left as they are.
  def journal_tag_toggle(active, tag)
    journal_tags_param(active.include?(tag) ? active - [tag] : active + [tag])
  end

  private

  def render_journal_body(rich_text)
    fragment = Nokogiri::HTML5.fragment(rich_text.to_s)
    fragment.css('pre').each { |node| highlight_code_block(node) }
    fragment.css('.jn-embed').each { |node| activate_embed(node) }
    fragment.to_html.html_safe # rubocop:disable Rails/OutputSafety -- Action Text sanitises on save
  end

  # Action Text's sanitiser strips data attributes, target and rel from rendered content, so
  # the embed partial emits a plain link and the interactive wiring is put back here — where
  # it applies only to markup our own partial produced, not to anything the author pasted.
  def activate_embed(node)
    facade = node.at_css('a.jn-embed__facade')
    return if facade.nil?

    node['data-controller'] = 'embed'
    node['data-embed-url-value'] = facade['href']
    facade['target'] = '_blank'
    facade['rel'] = 'noreferrer'
    facade['data-action'] = 'embed#load'
    node.at_css('.jn-embed__play')&.[]=('aria-hidden', 'true')
  end

  # Highlighting happens here, once, server-side — the public page, the admin preview and the
  # mobile view all read the same markup, and no syntax highlighter ships to the browser.
  # Anything Rouge does not have a lexer for stays plain rather than being guessed at.
  def highlight_code_block(node)
    code = node.at_css('code') || node
    lexer = lexer_for(code) || lexer_for(node)
    return if lexer.nil?

    node.replace(<<~HTML)
      <div class="jn-code">
        <span class="jn-code__lang">#{ERB::Util.html_escape(lexer.tag)}</span>
        <pre class="jn-code__body"><code>#{journal_highlight(code.text, lexer.tag)}</code></pre>
      </div>
    HTML
  end

  # Which language a listing claims to be in, off either element.
  #
  # It used to read the <code> alone, and TinyMCE's code-sample writes the class on the <pre>
  # around it — `<pre class="language-ruby"><code>`. So a listing inserted from the toolbar was
  # highlighted inside the editor, by the editor's own copy of Prism, and arrived on the page
  # grey: the one place the difference is invisible until it is published.
  #
  # `lang-` as well as `language-`, because that is the other spelling in the wild and costs a
  # single alternation to accept.
  def lexer_for(node)
    lexer_named(node['class'].to_s[/(?:language|lang)-([\w+-]+)/, 1])
  end

  # What an author types in the block's free-text language field is "Ruby " as often as "ruby".
  def lexer_named(name)
    token = name.to_s.strip.downcase
    return if token.empty?

    Rouge::Lexer.find(LEXER_ALIASES.fetch(token) { token })
  end
end
