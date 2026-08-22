# frozen_string_literal: true

module ProseHelper
  # Content strings carry inline <b>, <i> and <code> — and nothing else. They are meaning
  # (emphasised numbers, code identifiers), so they have to render as markup; anything beyond
  # those three tags is stripped. The models hand over an already-localised string, so there is
  # no language to pick here.
  RICH_TAGS = %w[b i code].freeze

  def rich(value)
    sanitize(value, tags: RICH_TAGS, attributes: [])
  end
end
