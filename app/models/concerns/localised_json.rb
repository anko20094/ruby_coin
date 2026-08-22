# frozen_string_literal: true

# Content that carries both languages inside JSONB, as {"en" => …, "uk" => …}.
#
# Used by Case and by the CV models. The handoff's YAML stores every translated string this
# way, so the database keeps the same shape rather than splitting it across a translations
# table — see redesign_plan.md §4.2 for where that leaves Mobility (Post only).
module LocalisedJson
  extend ActiveSupport::Concern

  private

  # A plain string passes through: some fields are proper nouns that read the same in both
  # languages, and the YAML writes those without a language pair.
  def localised(value)
    return value unless value.is_a?(Hash)

    value[I18n.locale.to_s].presence || value[I18n.default_locale.to_s]
  end

  def localised_pair(values)
    I18n.available_locales.to_h { |locale| [locale.to_s, values[locale.to_s]] }
  end
end
