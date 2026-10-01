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
    it 'builds one from a roster record, and keeps the machine flagged' do
      render_inline(described_class.of(Team.person!('claude'), size: 52, ring: :mute))

      expect(page).to have_css('.rc-monogram.rc-monogram--mute.rc-monogram--machine')
      expect(page).to have_css('.rc-monogram__flag')
    end

    it 'draws the photograph where the record has one' do
      render_inline(described_class.of(Team.person!('danyil'), size: 52))

      expect(page).to have_css('.rc-monogram--photo .rc-monogram__photo')
      expect(page).to have_no_css('.rc-monogram__initials')
    end

    # A 26px stone on a /work card fetched the same 560px file as the 280px one on a person page.
    it 'offers the photograph in three widths, for the browser to pick by the stone it draws' do
      render_inline(described_class.of(Team.person!('danyil'), size: 52))
      photo = page.find('.rc-monogram__photo')

      expect(photo[:srcset].split(', ').map { |candidate| candidate.split.last }).to eq(%w[120w 280w 560w])
      expect(photo[:srcset]).to match(%r{/assets/people/danyil-120-\h+\.jpg 120w})
      expect(photo[:sizes]).to eq('52px')
      expect(photo[:src]).to match(%r{/assets/people/danyil-\h+\.jpg})
    end

    it 'finds the smaller copies of a photograph that is a PNG' do
      render_inline(described_class.of(Team.person!('claude'), size: 26))

      expect(page.find('.rc-monogram__photo')[:srcset]).to match(%r{people/claude-120-\h+\.png 120w})
    end

    it 'ships every roster photograph in every width the component asks for' do
      photographed = Team.everyone.filter_map(&:photo)
      missing = photographed.product(described_class::PHOTO_WIDTHS).reject do |photo, width|
        Rails.application.assets.load_path.find(photo.sub(/(?=\.\w+\z)/, "-#{width}"))
      end

      expect(missing).to be_empty, "no smaller copy for: #{missing.map(&:inspect).join(', ')}"
    end

    # Initials are the finished state for a record with no photograph, not a missing one — the
    # frame, the ring and the radius are the same either way.
    it 'falls back to initials where it does not' do
      render_inline(described_class.of(Team.person!('oleksandr'), size: 52))

      expect(page).to have_no_css('.rc-monogram__photo')
      expect(page.find('.rc-monogram__initials').text).to eq('OS')
    end
  end

  # A person added with only the one file must still render: the page asks for what exists.
  it 'asks for the original alone where no smaller copy has been made' do
    load_path = Rails.application.assets.load_path
    allow(load_path).to(receive(:find).and_wrap_original { |find, path| find.call(path) unless path.match?(/-\d+\./) })
    render_inline(described_class.new(initials: 'DS', size: 52, photo: 'people/danyil.jpg'))

    expect(page).to have_css('.rc-monogram__photo[src]')
    expect(page).to have_no_css('.rc-monogram__photo[srcset], .rc-monogram__photo[sizes]')
  end

  it 'refuses a ring the design does not have' do
    expect { described_class.new(initials: 'DS', size: 26, ring: :gold) }.to raise_error(ArgumentError)
  end
end
