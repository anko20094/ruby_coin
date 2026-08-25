# frozen_string_literal: true

require 'rails_helper'

describe PhotoUploader do
  UPLOADS = Rails.root.join('tmp/uploads') # rubocop:disable Lint/ConstantDefinitionInBlock,RSpec/LeakyConstantDeclaration,Rails/FilePath

  # config/initializers/carrierwave.rb turns processing off for the whole test environment, so
  # that 480 specs do not each shell out to ImageMagick. This file is the one that has to have
  # it on: what it asserts is what ImageMagick was asked to do.
  # On this class, not through CarrierWave.configure. CarrierWave's config readers memoise
  # into an ivar on the uploader class the first time they are read, and the post factory has
  # already stored a photo by then — so setting it on the base class after that changes
  # nothing, which is why this file passed alone and skipped its own assertions in a full run.
  around do |example|
    described_class.enable_processing = true
    example.run
  ensure
    described_class.enable_processing = false
  end

  # The suite hook empties tmp/uploads, and `magick` writing into a directory that is not
  # there fails the same way a missing ImageMagick does — which is how this file came to skip
  # itself in a full run and pass on its own.
  before do
    FileUtils.mkdir_p(UPLOADS)
    MiniMagick.convert { |convert| convert.size('1x1') << 'xc:gray' << UPLOADS.join('probe.jpg').to_s }
  rescue StandardError => e
    skip "ImageMagick is not usable here: #{e.message.lines.first.to_s.strip}"
  end

  # Shapes rather than a fixture per case: what is being asserted is the arithmetic between a
  # source's proportions and a version's, and a generated image states that outright.
  def source(width, height)
    FileUtils.mkdir_p(UPLOADS)
    path = UPLOADS.join("source-#{width}x#{height}.jpg")
    MiniMagick.convert { |convert| convert.size("#{width}x#{height}") << 'xc:gray' << path.to_s }
    path
  end

  def versions_for(width, height)
    uploader = described_class.new(build(:post, id: 987_654), :photo)
    uploader.store!(File.open(source(width, height)))

    %i[medium small].index_with do |version|
      image = MiniMagick::Image.open(uploader.public_send(version).path)
      [image.width, image.height]
    end
  ensure
    uploader&.remove!
  end

  # The bug this file exists for. `resize_to_fill` enlarges, so the seeded 560×560 cover came
  # out as a 1200×675 JPEG: 2.14× bigger than anything actually in it, soft, and then cropped
  # again by the CSS into a 2.375:1 banner. A cover smaller than the slot should be a smaller
  # sharp file — the browser upscaling once beats ImageMagick upscaling first.
  it 'never enlarges a source that is smaller than the version' do
    versions = versions_for(560, 560)

    expect(versions[:medium]).to eq([560, 315])
    expect(versions[:medium].first).to be <= 560
    expect(versions[:small].first).to be <= 560
  end

  it 'still fills the version exactly when the source is big enough' do
    expect(versions_for(3000, 2000)).to eq(medium: described_class::MEDIUM, small: described_class::SMALL)
  end

  # A tall source has the width to spare in neither direction once it is cropped to 16:9.
  it 'crops a tall source to the version shape without inventing width' do
    medium = versions_for(1000, 3000)[:medium]

    expect(medium).to eq([1000, 563])
    wanted = described_class::MEDIUM.first.to_f / described_class::MEDIUM.last
    expect(medium.first.to_f / medium.last).to be_within(0.01).of(wanted)
  end

  it 'leaves a source smaller than every version alone but for the crop' do
    versions = versions_for(300, 200)

    expect(versions[:medium]).to eq([300, 169])
    expect(versions[:small]).to eq([300, 169])
  end
end
