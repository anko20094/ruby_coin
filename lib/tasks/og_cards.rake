# frozen_string_literal: true

# Share cards. One 1200×630 PNG per case per locale, plus one for the site, written to
# public/og/ and served as a static file.
#
# Every case link pasted into Telegram, LinkedIn or a DM used to unfurl as grey nothing, and
# those links are the whole point of this site (handoff README §9a, "the highest-value item on
# this list"). The handoff asks for the cards to be generated at deploy time rather than per
# request, through a headless browser rendering a real view — which is what this does, using
# Chrome directly instead of a gem wrapping it.
#
# The generated PNGs are committed. Cases change a few times a year and the images are ~40 KB
# each, so a file in the repo is both cheaper and more reliable than assuming a browser exists
# on the deploy target. Re-run this after editing a case title, tagline or first metric — or the
# home page's eyebrow, headline or lede, which are what the site card prints:
#
#     bin/rails runner 'Cases::Importer.call' && bundle exec rake og:cards
#
# The cards are drawn from the cases table, so the import comes first: a table that has drifted
# from config/portfolio/cases.yml gives cards the guard spec reads as stale.
#
# Set CHROME_BIN if the browser is somewhere unusual.
#
# public/og/cards.json holds a digest of each card's text, written with the PNGs;
# spec/requests/og_cards_spec.rb fails when a case or the home lede changes without a re-render.
module OgCards
  # Loaded again by the specs, and a constant reassigned warns.
  unless const_defined?(:CARD_SIZE)
    OgCards::CARD_SIZE = [1200, 630].freeze
    OgCards::OUTPUT_DIR = Rails.public_path.join('og')
    OgCards::MANIFEST = OgCards::OUTPUT_DIR.join('cards.json')
    OgCards::CHROME_CANDIDATES = %w[google-chrome google-chrome-stable chromium chromium-browser].freeze
    # The Cyrillic slices are declared with the same unicode-range the site uses. Without it the
    # last @font-face for a family wins for every character, so a Cyrillic slice that contains no
    # digits took the digits with it and "295" came out of a fallback face.
    CYRILLIC_RANGE = 'U+0301, U+0400-045F, U+0490-0491, U+04B0-04B1, U+2116'
    FONT_DIR = Rails.root.join('app', 'assets', 'fonts')
  end

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
  def strip_case_markup(value)
    ActionController::Base.helpers.strip_tags(value.to_s).strip
  end
end

namespace :og do
  desc 'Render the Open Graph share cards into public/og'
  task cards: :environment do
    browser = ENV['CHROME_BIN'].presence || OgCards::CHROME_CANDIDATES.find { |name| system('which', name, out: File::NULL) }
    abort "no Chrome found — set CHROME_BIN (tried: #{OgCards::CHROME_CANDIDATES.join(', ')})" if browser.nil?

    FileUtils.mkdir_p(OgCards::OUTPUT_DIR)
    written = OgCards.each_card.map { |locale, name, card| render_card(browser, locale, name, card) }
    OgCards::MANIFEST.write("#{JSON.pretty_generate(OgCards.digests)}\n")

    puts "wrote #{written.size} cards:"
    written.each { |path| puts "  #{path.relative_path_from(Rails.root)} (#{(path.size / 1024.0).round} KB)" }
  end

  # --- rendering ----------------------------------------------------------------------------

  def render_card(browser, locale, name, locals)
    html = ApplicationController.render(
      template: 'og/card', layout: false,
      assigns: {},
      locals: locals.merge(locale: locale, fonts: inlined_faces(locale), gem: gem_svg)
    )

    page = Rails.root.join('tmp', "og-#{locale}-#{name}.html")
    page.write(html)
    output = OgCards::OUTPUT_DIR.join("#{name}-#{locale}.png")

    ok = system(browser, '--headless', '--disable-gpu', '--no-sandbox', '--hide-scrollbars',
                "--screenshot=#{output}", "--window-size=#{OgCards::CARD_SIZE.join(',')}",
                "file://#{page}", out: File::NULL, err: File::NULL)
    abort "#{browser} failed on #{name}-#{locale}" unless ok && output.exist?

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
      face('Display', "#{display}-cyrillic", range: OgCards::CYRILLIC_RANGE, optional: true),
      face('Geist', 'geist-400-cyrillic', range: OgCards::CYRILLIC_RANGE),
      face('JetBrains Mono', 'jetbrains-mono-400-cyrillic', range: OgCards::CYRILLIC_RANGE),
      face('Display', "#{display}-latin"),
      face('Geist', 'geist-400-latin'),
      face('JetBrains Mono', 'jetbrains-mono-400-latin')
    ].compact.join("\n")
  end

  # Instrument Serif has no Cyrillic slice on disk at all, which is the whole reason the
  # Ukrainian pages use EB Garamond — so that one request is allowed to come back empty.
  def face(family, slice, range: nil, optional: false)
    path = OgCards::FONT_DIR.join("#{slice}.woff2")
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
