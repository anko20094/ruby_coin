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
# on the deploy target. Re-run this after editing a case title, tagline or first metric:
#
#     bundle exec rake og:cards
#
# Set CHROME_BIN if the browser is somewhere unusual.
module OgCards
  OgCards::CARD_SIZE = [1200, 630].freeze
  OgCards::OUTPUT_DIR = Rails.public_path.join('og')
  OgCards::CHROME_CANDIDATES = %w[google-chrome google-chrome-stable chromium chromium-browser].freeze
  # The Cyrillic slices are declared with the same unicode-range the site uses. Without it the
  # last @font-face for a family wins for every character, so a Cyrillic slice that contains no
  # digits took the digits with it and "295" came out of a fallback face.
  CYRILLIC_RANGE = 'U+0301, U+0400-045F, U+0490-0491, U+04B0-04B1, U+2116'
  FONT_DIR = Rails.root.join('app', 'assets', 'fonts')
end

namespace :og do
  desc 'Render the Open Graph share cards into public/og'
  task cards: :environment do
    browser = ENV['CHROME_BIN'].presence || OgCards::CHROME_CANDIDATES.find { |name| system('which', name, out: File::NULL) }
    abort "no Chrome found — set CHROME_BIN (tried: #{OgCards::CHROME_CANDIDATES.join(', ')})" if browser.nil?

    FileUtils.mkdir_p(OgCards::OUTPUT_DIR)
    written = []

    I18n.available_locales.each do |locale|
      I18n.with_locale(locale) do
        written << render_card(browser, locale, 'site', site_card(locale))

        Case.ordered.each do |kase|
          written << render_card(browser, locale, kase.slug, case_card(kase))
        end
      end
    end

    puts "wrote #{written.size} cards:"
    written.each { |path| puts "  #{path.relative_path_from(Rails.root)} (#{(path.size / 1024.0).round} KB)" }
  end

  # --- what goes on a card ------------------------------------------------------------------

  def case_card(kase)
    {
      mark: kase.mark,
      eyebrow: [kase.sector, kase.year].compact_blank.join(' · '),
      title: kase.title,
      tagline: kase.tagline,
      metric: kase.metrics.first
    }
  end

  def site_card(locale)
    profile = CVProfile.current

    {
      mark: nil,
      eyebrow: I18n.t('work.index.eyebrow', locale: locale),
      title: profile.name,
      tagline: profile.summary,
      metric: nil
    }
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
