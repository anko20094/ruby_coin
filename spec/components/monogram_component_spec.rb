# frozen_string_literal: true

require 'rails_helper'

describe MonogramComponent, type: :component do
  it 'draws the initials, and is decoration as far as a screen reader is concerned' do
    render_inline(described_class.new(initials: 'DS', size: 88))

    expect(page).to have_css('.rc-monogram[aria-hidden="true"]')
    expect(page.find('.rc-monogram__initials').text).to eq('DS')
  end

  it 'carries the size as a custom property, so one component is 26px and 280px' do
    render_inline(described_class.new(initials: 'DS', size: 280))

    expect(page.find('.rc-monogram')[:style]).to include('--monogram-size: 280px')
  end

  # Same person, same stone, every time: the gradient angle is seeded from the id.
  it 'leans the gradient the same way for the same person' do
    angles = Array.new(2) do
      render_inline(described_class.new(initials: 'NT', seed: 'natalia', size: 76))
      page.find('.rc-monogram')[:style][/--monogram-angle: (\d+)deg/, 1]
    end

    expect(angles.uniq.size).to eq(1)
  end

  it 'leans it differently for different people' do
    styles = %w[danyil natalia].map do |id|
      render_inline(described_class.new(initials: 'XX', seed: id, size: 76))
      page.find('.rc-monogram')[:style]
    end

    expect(styles.uniq.size).to eq(2)
  end

  # The reader is told what it is, immediately, without a footnote.
  it 'flags a machine' do
    render_inline(described_class.new(initials: 'C', machine: true, size: 76))

    expect(page.find('.rc-monogram__flag').text).to eq('CI')
  end

  it 'leaves the flag off a person' do
    render_inline(described_class.new(initials: 'DS', size: 76))

    expect(page).to have_no_css('.rc-monogram__flag')
  end

  # On a /work card the faces are 26px, where "CI" is a smudge rather than a word. The ring
  # carries the label there instead — an unlabelled bot among four faces is the one thing the
  # roster must not ship.
  it 'marks a machine drawn too small for its label' do
    render_inline(described_class.new(initials: 'C', machine: true, size: 26, ring: :paper))

    expect(page).to have_css('.rc-monogram--machine.rc-monogram--compact')
  end

  it 'leaves a person that small unmarked' do
    render_inline(described_class.new(initials: 'DS', size: 26, ring: :paper))

    expect(page).to have_css('.rc-monogram--compact')
    expect(page).to have_no_css('.rc-monogram--machine')
  end

  describe '.of' do
    it 'builds one from a roster record' do
      render_inline(described_class.of(Team.person!('claude'), size: 52, ring: :mute))

      expect(page).to have_css('.rc-monogram.rc-monogram--mute')
      expect(page).to have_css('.rc-monogram__flag')
      expect(page.find('.rc-monogram__initials').text).to eq('C')
    end
  end

  it 'refuses a ring the design does not have' do
    expect { described_class.new(initials: 'DS', size: 26, ring: :gold) }.to raise_error(ArgumentError)
  end
end
