# frozen_string_literal: true

module ProseHelper
  # Case content is edited in TinyMCE and stored as a string per language, so it arrives here
  # as markup. The editor there is deliberately inline-only — no paragraphs, no lists — because
  # every one of these strings is printed inside markup the /work design already owns: a <p>,
  # an <li>, an <h3>. A block-level editor would nest a paragraph inside a list item.
  #
  # This list is therefore the inline set and nothing else, and it is the same list the case
  # profile in app/javascript/controllers/tinymce_controller.js gives TinyMCE as
  # `valid_elements`. The two have to agree: anything the toolbar can make and this strips is
  # a change the author watches disappear on save.
  RICH_TAGS = %w[b strong i em code a br u s sup sub span].freeze
  RICH_ATTRIBUTES = %w[href title target rel class].freeze

  def rich(value)
    sanitize(value, tags: RICH_TAGS, attributes: RICH_ATTRIBUTES)
  end

  # The same string with the markup taken back off, for the places that cannot render it: a
  # <title>, a meta description, an OG card baked to PNG, the text a metric copies to the
  # clipboard. Without this the reader gets "<b>2.14M</b>" in their paste buffer.
  def plain(value)
    strip_tags(value.to_s).strip
  end
end
