# frozen_string_literal: true

module ThemeHelper
  # The two faces worth a preload hint: the display face that draws the headline, and the body
  # face that draws the lede under it. Between them they are the first screen.
  #
  # The mono and italic cuts are deliberately not here any more. They are real — mono labels
  # and the italic mark appear on every page — but they are small text, they carry
  # font-display: swap, and preloading them meant an English page opened four font connections
  # totalling 103 KB in parallel with the stylesheet. On a 400 kbps line that is two seconds of
  # bandwidth spent ahead of the CSS to avoid a flash on a middot. They load when the CSS
  # names them, like any other face.
  #
  # The display face differs per locale on purpose — Instrument Serif has no Cyrillic subset at
  # all, so Ukrainian pages run on EB Garamond throughout (theme/_base.scss). Asking for a
  # slice that does not exist would raise in Propshaft, so the two locales get separate lists
  # rather than one template.
  PRELOADED_FACES = {
    en: %w[instrument-serif-400-latin geist-400-latin],
    uk: %w[eb-garamond-400-cyrillic geist-400-cyrillic]
  }.freeze

  def theme_preloaded_faces
    PRELOADED_FACES.fetch(I18n.locale, PRELOADED_FACES[:en])
  end

  # Rails, Devise and Pundit each name the same two states differently. Two tones is all the
  # design has, so everything lands in one of them rather than growing a colour per key.
  ALERT_KEYS = %w[alert error danger].freeze

  def flash_tone(type)
    ALERT_KEYS.include?(type.to_s) ? 'alert' : 'notice'
  end
end
