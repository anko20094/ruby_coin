# frozen_string_literal: true

module OgCards
  CARD_SIZE = [1200, 630].freeze
  OUTPUT_DIR = Rails.public_path.join('og')
  MANIFEST = OUTPUT_DIR.join('cards.json')
  CHROME_CANDIDATES = %w[google-chrome google-chrome-stable chromium chromium-browser].freeze
  # The Cyrillic slices are declared with the same unicode-range the site uses. Without it the
  # last @font-face for a family wins for every character, so a Cyrillic slice that contains no
  # digits took the digits with it and "295" came out of a fallback face.
  CYRILLIC_RANGE = 'U+0301, U+0400-045F, U+0490-0491, U+04B0-04B1, U+2116'
  FONT_DIR = Rails.root.join('app', 'assets', 'fonts')

  class RenderError < StandardError; end

  module_function

  # Yields every card with the locale it is drawn in, inside that locale.
  def each_card
    return enum_for(:each_card) unless block_given?

    I18n.available_locales.each do |locale|
      I18n.with_locale(locale) do
        yield locale, 'site', site_card(locale)

        Case.ordered.each { |kase| yield locale, kase.slug, case_card(kase) }
      end
    end
  end

  def digests
    each_card.to_h { |locale, name, card| ["#{name}-#{locale}", digest(card)] }
  end

  def digest(card) = Digest::SHA256.hexdigest(card.to_json)[0, 16]

  # The digests the committed cards were drawn with, by card name ("dna-en"). Read once per
  # process, except where the files are being edited.
  def recorded
    return read_manifest if Rails.application.config.enable_reloading

    @recorded ||= read_manifest
  end

  def read_manifest
    MANIFEST.exist? ? JSON.parse(MANIFEST.read) : {}
  end

  # --- what goes on a card ------------------------------------------------------------------

  def case_card(kase)
    {
      mark: kase.mark,
      eyebrow: [kase.sector, kase.year].compact_blank.join(' · '),
      title: strip_case_markup(kase.title),
      tagline: strip_case_markup(kase.tagline),
      metric: kase.metrics.first&.transform_values { |value| strip_case_markup(value) }
    }
  end

  # Everything that is not a case unfurls with this one: the home page, /work, /team, a person
  # page, /studio, /cv. It used to be built from the CV, so a link to the roster — six people —
  # arrived in a chat under one person's name and his first-person summary. It says what the
  # site says instead, in the site's own words.
  def site_card(locale)
    headline = %w[headline_lead headline_join headline_mark]
               .map { |key| I18n.t("home.index.#{key}", locale: locale) }
               .compact_blank.join(' ')

    {
      mark: nil,
      eyebrow: I18n.t('home.index.eyebrow', locale: locale),
      title: "#{headline}.",
      tagline: I18n.t('home.index.lede_2', locale: locale),
      metric: nil
    }
  end

  # A case field is TinyMCE markup now. The card is baked to a PNG by a browser that would
  # happily render a <b> — but the title also sizes itself by character count, and an OG card
  # is not the place for a bolded word. The words go on, the markup does not.
  #
  # Not ProseHelper.plain: that also unescapes, and the recorded digests are of this text.
  def strip_case_markup(value)
    ActionController::Base.helpers.strip_tags(value.to_s).strip
  end

  # --- rendering ----------------------------------------------------------------------------

  def chrome
    ENV['CHROME_BIN'].presence || CHROME_CANDIDATES.find { |name| system('which', name, out: File::NULL) }
  end

  # Every card through the browser, then the manifest. Returns the paths written.
  def render_all(browser)
    FileUtils.mkdir_p(OUTPUT_DIR)
    written = each_card.map { |locale, name, card| render_card(browser, locale, name, card) }
    MANIFEST.write("#{JSON.pretty_generate(digests)}\n")
    @recorded = nil
    written
  end

  def render_card(browser, locale, name, locals)
    html = ApplicationController.render(
      template: 'og/card', layout: false,
      assigns: {},
      locals: locals.merge(locale: locale, fonts: inlined_faces(locale), gem: gem_svg)
    )

    page = Rails.root.join('tmp', "og-#{locale}-#{name}.html")
    page.write(html)
    output = OUTPUT_DIR.join("#{name}-#{locale}.png")

    # --password-store/--use-mock-keychain: no desktop keyring prompt on Linux.
    ok = system(browser, '--headless', '--disable-gpu', '--no-sandbox', '--hide-scrollbars',
                '--password-store=basic', '--use-mock-keychain',
                "--screenshot=#{output}", "--window-size=#{CARD_SIZE.join(',')}",
                "file://#{page}", out: File::NULL, err: File::NULL)
    raise RenderError, "#{browser} failed on #{name}-#{locale}" unless ok && output.exist?

    page.delete
    output
  end

  # The display face is locale-dependent for the same reason the site is: Instrument Serif has
  # no Cyrillic at all, so a Ukrainian card is set in EB Garamond throughout.
  #
  # Both the Latin and Cyrillic slices go in whatever the locale. Digits and punctuation live
  # only in the Latin subset, so a Ukrainian card built from the Cyrillic slice alone rendered
  # "295 commits" in a fallback face — the one thing on the card that has to be mono.
  def inlined_faces(locale)
    display = locale == :uk ? 'eb-garamond-400' : 'instrument-serif-400'

    [
      face('Display', "#{display}-cyrillic", range: CYRILLIC_RANGE, optional: true),
      face('Geist', 'geist-400-cyrillic', range: CYRILLIC_RANGE),
      face('JetBrains Mono', 'jetbrains-mono-400-cyrillic', range: CYRILLIC_RANGE),
      face('Display', "#{display}-latin"),
      face('Geist', 'geist-400-latin'),
      face('JetBrains Mono', 'jetbrains-mono-400-latin')
    ].compact.join("\n")
  end

  # Instrument Serif has no Cyrillic slice on disk at all, which is the whole reason the
  # Ukrainian pages use EB Garamond — so that one request is allowed to come back empty.
  def face(family, slice, range: nil, optional: false)
    path = FONT_DIR.join("#{slice}.woff2")
    return nil if optional && !path.exist?

    <<~CSS
      @font-face {
        font-family: '#{family}';
        font-style: normal;
        font-weight: 400;
        src: url(data:font/woff2;base64,#{Base64.strict_encode64(path.binread)}) format('woff2');
        #{"unicode-range: #{range};" if range}
      }
    CSS
  end

  # The same ruby the site draws, painted server-side by the same component.
  def gem_svg
    ApplicationController.render(GemComponent.new(uid: 'og', variant: :logo), layout: false)
  end
end
