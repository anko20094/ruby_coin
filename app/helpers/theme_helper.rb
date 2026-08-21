# frozen_string_literal: true

module ThemeHelper
  # The faces worth a preload hint: the display face in both cuts (headlines and
  # the italic ledes sit above the fold), plus body and mono at 400.
  #
  # The display face differs per locale on purpose — Instrument Serif has no
  # Cyrillic subset at all, so Ukrainian pages run on EB Garamond throughout
  # (theme/_base.scss). Asking for a slice that does not exist would raise in
  # Propshaft, so the two locales get separate lists rather than one template.
  PRELOADED_FACES = {
    en: %w[instrument-serif-400-latin instrument-serif-400-italic-latin geist-400-latin jetbrains-mono-400-latin],
    uk: %w[eb-garamond-400-cyrillic eb-garamond-400-italic-cyrillic geist-400-cyrillic jetbrains-mono-400-cyrillic]
  }.freeze

  def theme_preloaded_faces
    PRELOADED_FACES.fetch(I18n.locale, PRELOADED_FACES[:en])
  end
end
