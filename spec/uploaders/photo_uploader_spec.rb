# frozen_string_literal: true

require 'rails_helper'

describe PhotoUploader do
  # config/initializers/carrierwave.rb turns processing off for the whole test environment, so
  # that the specs that only need a cover do not each shell out to ImageMagick. This file is
  # the one that has to have it on: what it asserts is what ImageMagick was asked to do.
  # On this class, not through CarrierWave.configure: the config readers memoise into an ivar
  # on the uploader class the first time they are read, so setting it on the base class after
  # the post factory has stored a photo changes nothing.
  around do |example|
    described_class.enable_processing = true
    example.run
  ensure
    described_class.enable_processing = false
  end

  before do
    skip 'ImageMagick is not installed' unless MiniMagick::Utilities.which('magick') || MiniMagick::Utilities.which('convert')
  end

  let(:scratch) { Pathname(Dir.mktmpdir('photo-uploader', Rails.root.join('tmp'))) }
  let(:stored) { [] }
  let(:cache_root) { Pathname(described_class.root).join(described_class.cache_dir) }

  after do
    stored.each(&:remove!)
    FileUtils.rm_rf(scratch)
  end

  def plain(name, width, height) = ImageFixtures.plain_image(scratch.join(name), width: width, height: height)

  def store(path, declared: nil)
    uploader = described_class.new(Post.new(id: 987_654), :photo)
    upload = declared ? Rack::Test::UploadedFile.new(path, declared) : File.open(path)
    uploader.store!(upload)
    stored << uploader
    uploader
  end

  def image(path) = MiniMagick::Image.new(path.to_s)

  def sizes(uploader)
    %i[medium small].index_with do |version|
      picture = image(uploader.public_send(version).path)
      [picture.width, picture.height]
    end
  end

  def pixel(path, column, row) = image(path).get_pixels[row][column]

  def version_paths(uploader) = [uploader.medium.path, uploader.small.path]

  # `resize_to_fill` enlarges, so a 560×560 source used to come out as a 1200×675 JPEG: 2.14×
  # bigger than anything actually in it, and soft. A cover smaller than the slot should be a
  # smaller sharp file — the browser upscaling once beats ImageMagick upscaling first.
  describe 'geometry' do
    it 'never enlarges a source that is smaller than the version' do
      versions = sizes(store(plain('square.jpg', 560, 560)))

      expect(versions[:medium]).to eq([560, 315])
      expect(versions[:medium].first).to be <= 560
      expect(versions[:small].first).to be <= 560
    end

    it 'still fills the version exactly when the source is big enough' do
      expect(sizes(store(plain('wide.jpg', 3000, 2000)))).to eq(medium: described_class::MEDIUM,
                                                                small: described_class::SMALL)
    end

    it 'crops a tall source to the version shape without inventing width' do
      medium = sizes(store(plain('tall.jpg', 1000, 3000)))[:medium]

      expect(medium).to eq([1000, 563])
      wanted = described_class::MEDIUM.first.to_f / described_class::MEDIUM.last
      expect(medium.first.to_f / medium.last).to be_within(0.01).of(wanted)
    end

    it 'leaves a source smaller than every version alone but for the crop' do
      versions = sizes(store(plain('tiny.jpg', 300, 200)))

      expect(versions[:medium]).to eq([300, 169])
      expect(versions[:small]).to eq([300, 169])
    end

    it 'cuts a portrait phone photo from the upright picture, not from the sensor frame' do
      phone = ImageFixtures.jpeg_with_exif(scratch.join('phone.jpg'), width: 3000, height: 2000, orientation: 6)
      uploader = store(phone)

      expect(sizes(uploader)).to eq(medium: described_class::MEDIUM, small: described_class::SMALL)
      expect(image(uploader.path).dimensions).to eq([2000, 3000])
    end

    it 'cuts exactly two versions' do
      uploader = store(plain('wide.jpg', 3000, 2000))

      expect(described_class.versions.keys).to eq(%i[medium small])
      expect(Dir.children(File.dirname(uploader.path)).size).to eq(3)
    end
  end

  describe 'encoding' do
    it 'writes both versions as progressive JPEG at quality 80 from a JPEG source' do
      version_paths(store(plain('wide.jpg', 3000, 2000))).each do |path|
        expect(image(path).type).to eq('JPEG')
        expect(image(path)['%Q']).to eq('80')
        expect(image(path)['%[interlace]']).to eq('JPEG')
      end
    end

    it 'writes the same JPEG at quality 80 from a PNG source' do
      version_paths(store(plain('screenshot.png', 2400, 1600))).each do |path|
        expect(image(path).type).to eq('JPEG')
        expect(image(path)['%Q']).to eq('80')
        expect(image(path)['%[interlace]']).to eq('JPEG')
      end
    end

    it 'flattens a transparent source onto white, not black' do
      uploader = store(ImageFixtures.png_with_alpha(scratch.join('logo.png'), width: 1600, height: 900))

      version_paths(uploader).each do |path|
        expect(pixel(path, 0, 0)).to eq([255, 255, 255])
        expect(pixel(path, image(path).width / 2, image(path).height / 2)).to eq([254, 0, 0])
      end
    end

    it 'flattens a transparent source that is named as a JPEG onto white, not black' do
      named = scratch.join('logo.jpg')
      FileUtils.cp(ImageFixtures.png_with_alpha(scratch.join('logo.png'), width: 1600, height: 900), named)
      uploader = store(named, declared: 'image/png')

      expect(pixel(uploader.path, 0, 0)).to eq([255, 255, 255])
    end

    it 'keeps the first frame of an animated GIF' do
      uploader = store(ImageFixtures.animated_gif(scratch.join('loop.gif')))

      [uploader.path, *version_paths(uploader)].each { |path| expect(image(path).layers.size).to eq(1) }
    end
  end

  # A phone photo carries the camera and the GPS position. The original is a public file next
  # to its versions, so it is as much a part of the page as they are.
  describe 'metadata' do
    let(:phone) { ImageFixtures.jpeg_with_exif(scratch.join('phone.jpg'), width: 1600, height: 900) }

    it 'starts from a source that has it' do
      expect(File.binread(phone)).to include(ImageFixtures::CAMERA_MAKE, 'Exif')
      expect(image(phone).exif).to include('Make' => ImageFixtures::CAMERA_MAKE, 'GPSLatitude' => '50/1,27/1,0/1')
    end

    it 'strips it from the stored original and from both versions' do
      uploader = store(phone)

      [uploader.path, *version_paths(uploader)].each do |path|
        expect(File.binread(path)).not_to include(ImageFixtures::CAMERA_MAKE, 'Exif')
        expect(image(path).exif).to be_empty
      end
    end
  end

  describe 'names' do
    it 'ignores what the client called the file' do
      uploader = store(plain('My Cover.PNG', 800, 450))

      expect(uploader.identifier).to match(/\A\d{14}-\h{8}\.png\z/)
      expect(File.basename(uploader.medium.path)).to eq("medium_#{uploader.identifier.sub('.png', '.jpg')}")
      expect(File.basename(uploader.small.path)).to eq("small_#{uploader.identifier.sub('.png', '.jpg')}")
    end

    it 'gives two covers uploaded under one name two different paths' do
      source = plain('cover.jpg', 800, 450)

      expect(store(source).path).not_to eq(store(source).path)
    end
  end

  describe 'what it accepts' do
    it 'refuses an SVG renamed to .jpg even when it says image/jpeg' do
      svg = scratch.join('mark.jpg')
      svg.write('<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"><rect width="10" height="10"/></svg>')

      expect { store(svg, declared: 'image/jpeg') }.to raise_error(CarrierWave::IntegrityError, %r{image/svg\+xml})
    end

    it 'refuses a TIFF renamed to .jpg' do
      tiff = scratch.join('scan.jpg')
      MiniMagick.convert { |convert| convert.size('10x10') << 'xc:gray' << "tiff:#{tiff}" }

      expect { store(tiff, declared: 'image/jpeg') }.to raise_error(CarrierWave::IntegrityError)
    end

    it 'refuses a text file renamed to .jpg' do
      script = scratch.join('payload.jpg')
      script.write('<?php system($_GET["c"]); ?>')

      expect { store(script) }.to raise_error(CarrierWave::IntegrityError)
    end

    it 'refuses a file ImageMagick cannot decode, whatever the client says it is' do
      script = scratch.join('payload.jpg')
      script.write("push graphic-context\nfill red\npop graphic-context\n")

      expect { store(script, declared: 'image/jpeg') }.to raise_error(CarrierWave::ProcessingError)
    end

    it 'refuses an extension that is not a picture' do
      pdf = scratch.join('cover.pdf')
      FileUtils.cp(plain('cover.jpg', 100, 100), pdf)

      expect { store(pdf) }.to raise_error(CarrierWave::IntegrityError)
    end

    it 'refuses a file over the size limit' do
      stub_const('PhotoUploader::MAX_BYTES', 1.kilobyte)

      expect { store(plain('wide.jpg', 3000, 2000)) }.to raise_error(CarrierWave::IntegrityError)
    end
  end

  # A save that fails validation caches the upload and never stores it, and the editor sends
  # the file again on every autosave until the form is valid.
  describe 'the cache' do
    it 'removes what is a day old the next time something is cached, and keeps what is not' do
      stale = cache_root.join("#{2.days.ago.to_i}-1234-0001-0002")
      fresh = cache_root.join("#{1.hour.ago.to_i}-1234-0001-0003")
      [stale, fresh].each { |dir| FileUtils.mkdir_p(dir) && FileUtils.touch(dir.join('cover.jpg')) }

      store(plain('wide.jpg', 800, 450))

      expect(stale).not_to exist
      expect(fresh).to exist
    end
  end
end
