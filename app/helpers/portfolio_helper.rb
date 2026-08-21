# frozen_string_literal: true

module PortfolioHelper
  # Content strings carry inline <b>, <i> and <code> — and nothing else. They
  # are meaning (emphasised numbers, code identifiers), so they have to render
  # as markup; anything beyond those three tags is stripped.
  RICH_TAGS = %w[b i code].freeze

  # Picks the localised half of a { en:, uk: } pair. Plain strings pass through.
  def t_field(value)
    return value if value.is_a?(String) || value.nil?

    value[I18n.locale.to_s] || value['en']
  end

  def rich(value)
    sanitize(t_field(value), tags: RICH_TAGS, attributes: [])
  end
end
