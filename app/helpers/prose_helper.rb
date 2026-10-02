# frozen_string_literal: true

module ProseHelper
  # Case content is edited in TinyMCE and stored as a string per language, so it arrives here
  # as markup. The editor there is deliberately inline-only — no paragraphs, no lists — because
  # every one of these strings is printed inside markup the /work design already owns: a <p>,
  # an <li>, an <h3>. A block-level editor would nest a paragraph inside a list item.
  #
  # This list is therefore the inline set and nothing else, and the case editor is built from
  # it (TinymceHelper#tinymce_valid_elements): anything the toolbar can make and this strips is
  # a change the author watches disappear on save.
  RICH_MARKUP = {
    'b' => [], 'strong' => [], 'i' => [], 'em' => [], 'code' => [], 'br' => [],
    'u' => [], 's' => [], 'sup' => [], 'sub' => [],
    'a' => %w[href title target rel],
    'span' => %w[class]
  }.freeze
  RICH_TAGS = RICH_MARKUP.keys.freeze
  RICH_ATTRIBUTES = RICH_MARKUP.values.flatten.uniq.freeze
  RICH_TAGS_WITHOUT_LINKS = (RICH_TAGS - %w[a]).freeze

  # `links: false` for text printed inside a card, which is itself a link or a button: the
  # parser closes the outer <a> at the inner one, and half the card stops being clickable.
  def rich(value, links: true)
    sanitize(value, tags: links ? RICH_TAGS : RICH_TAGS_WITHOUT_LINKS, attributes: RICH_ATTRIBUTES)
  end

  # The same string with the markup taken back off, for the places that cannot render it: a
  # <title>, a meta description, an OG card baked to PNG, the text a metric copies to the
  # clipboard — otherwise the paste buffer gets "<b>…</b>".
  #
  # Unescaped, because strip_tags escapes what it keeps and every one of those call sites
  # escapes again on the way out — "&" would arrive as "&amp;".
  delegate :plain, to: :ProseHelper

  # The same, outside a view: the palette answers JSON from a service.
  def self.plain(value)
    CGI.unescapeHTML(ActionController::Base.helpers.strip_tags(value.to_s)).strip
  end
end
