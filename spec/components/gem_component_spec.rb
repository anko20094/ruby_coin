# frozen_string_literal: true

require 'rails_helper'

describe GemComponent, type: :component do
  it 'cuts the stone into six crown facets plus a table and a girdle' do
    render_inline(described_class.new(uid: 'spec'))

    expect(page).to have_css('polygon[fill^="url(#rc-gem-f"]', count: 6)
    expect(page).to have_css('polygon[fill="url(#rc-gem-table-spec)"]', count: 1)
    expect(page).to have_css('polygon[stroke="currentColor"]', count: 1)
  end

  # Locks the shading port down: these values came from the prototype's own
  # output, so a change in the maths shows up here rather than in someone's eye.
  it 'shades the facet under the light exactly as the prototype did' do
    render_inline(described_class.new(uid: 'spec'))

    stops = page.all('#rc-gem-f5-spec stop').pluck(:'stop-color')

    expect(stops).to eq(['oklch(75.1% 0.290 14.3)', 'oklch(63.6% 0.251 15.3)', 'oklch(49.5% 0.202 16.7)'])
  end

  it 'shimmers on the brightest facet only' do
    render_inline(described_class.new(uid: 'spec'))

    expect(page).to have_css('polygon[points="26.49,25.38 40.43,17.33 40.43,25.73 33.76,29.58"]')
  end

  describe 'the static logo' do
    it 'carries no controller and no dead placeholders' do
      render_inline(described_class.new(uid: 'spec'))

      expect(page).to have_no_css('[data-controller="ruby"]')
      expect(page).to have_no_css('[data-ruby-target="star"]')
      expect(page).to have_no_css('filter')
    end
  end

  describe 'the badge' do
    it 'is driven by the controller but carries no glow' do
      render_inline(described_class.new(uid: 'spec', variant: :badge, tone: 2))

      expect(page).to have_css('[data-controller="ruby"][data-ruby-variant-value="badge"]')
      expect(page).to have_css('[data-ruby-target="star"]')
      expect(page).to have_no_css('filter')
    end
  end

  describe 'the interactive cuts' do
    it 'hand the controller everything it drives' do
      render_inline(described_class.new(uid: 'spec', variant: :hero, size: 400))

      expect(page).to have_css('[data-controller="ruby"][data-ruby-variant-value="hero"]')
      expect(page).to have_css('[data-ruby-target="facet"]', count: 6)
      expect(page).to have_css('[data-ruby-target="facetGradient"]', count: 6)
      expect(page).to have_css('[data-ruby-target="tableGradient"]')
      expect(page).to have_css('[data-ruby-target="crown"]')
    end

    it 'glows, unlike the logo' do
      render_inline(described_class.new(uid: 'spec', variant: :anchor))

      expect(page).to have_css('filter#rc-gem-glow-spec')
    end

    # A ceiling, not a fixed width: a 400px gem in a one-column grid used to pin the home
    # page's min-content at 400px and push it 61px past a 375px phone.
    #
    # max-width rather than min(), because a width computed from a percentage leaves the SVG an
    # indefinitely-sized replaced element, whose max-content contribution is the 300px an SVG
    # falls back to. The floating back-to-top button is shrink-to-fit around one of these: it
    # came out 312px wide and covered the footer's contact links with its invisible half.
    it 'takes its size from the caller as a maximum it may shrink below' do
      render_inline(described_class.new(uid: 'spec', variant: :hero, size: 400))

      expect(page.find('svg')[:style]).to eq('width: 400px; max-width: 100%; height: auto; aspect-ratio: 1')
    end
  end

  describe 'a tone' do
    def stops(tone)
      render_inline(described_class.new(uid: 'spec', tone:))
      page.all('#rc-gem-f5-spec stop').pluck(:'stop-color')
    end

    it 'leaves the brand ruby exactly as it was at tone zero' do
      expect(stops(0)).to eq(['oklch(75.1% 0.290 14.3)', 'oklch(63.6% 0.251 15.3)', 'oklch(49.5% 0.202 16.7)'])
    end

    # Hue, lightness and chroma move together but only a little: every shade is still a ruby.
    it 'shifts the stone to another shade of the same ruby' do
      expect(stops(1)).to eq(['oklch(77.1% 0.290 2.3)', 'oklch(65.6% 0.251 3.3)', 'oklch(51.5% 0.202 4.7)'])
    end

    it 'keeps every shade within a narrow band of the brand hue' do
      described_class::TONES.size.times do |tone|
        hues = stops(tone).map { |stop| stop[/ ([\d.]+)\)\z/, 1].to_f }

        expect(hues).to all(satisfy { |hue| hue <= 30 || hue >= 350 })
      end
    end

    it 'takes any integer round the table, so an id or a position will do' do
      expect(stops(described_class::TONES.size + 1)).to eq(stops(1))
    end

    it 'hands the interactive cut its tone, and only when it is not the default' do
      render_inline(described_class.new(uid: 'spec', variant: :hero, tone: 2))
      expect(page).to have_css('[data-ruby-tone-value="2"]')
      expect(page).to have_no_css('polygon[fill="oklch(58% 0.22 18)"]')

      render_inline(described_class.new(uid: 'spec', variant: :hero))
      expect(page).to have_no_css('[data-ruby-tone-value]')
      expect(page).to have_css('polygon[fill="oklch(58% 0.22 18)"][data-ruby-target="glow"]')
    end

    # The controller has no table of its own: what it paints with is what TONES says.
    it 'hands the hero the whole table and a glow per shade, so a click can move it on' do
      render_inline(described_class.new(uid: 'spec', variant: :hero))
      svg = page.find('svg')

      expect(JSON.parse(svg['data-ruby-tones-value'])).to eq(described_class::TONES)
      expect(JSON.parse(svg['data-ruby-glows-value']))
        .to eq(described_class::TONES.each_index.map { |tone| described_class.new(uid: 'x', tone:).glow_colour })
    end

    it 'hands every other interactive cut its own shade alone, and the static logo nothing' do
      render_inline(described_class.new(uid: 'spec', variant: :badge, tone: 3))
      svg = page.find('svg')
      expect(JSON.parse(svg['data-ruby-tones-value'])).to eq([described_class::TONES[3]])
      expect(svg['data-ruby-glows-value']).to be_nil

      render_inline(described_class.new(uid: 'spec', tone: 3))
      expect(page).to have_no_css('[data-ruby-tones-value]')
    end
  end

  it 'refuses an unknown variant' do
    expect { described_class.new(uid: 'spec', variant: :sparkle) }.to raise_error(ArgumentError, /variant must be/)
  end
end
