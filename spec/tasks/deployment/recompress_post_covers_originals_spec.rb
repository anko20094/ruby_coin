# frozen_string_literal: true

require 'rails_helper'

# The covers this task finds were stored by the uploader before it stripped anything: the original
# is a public file with the camera's EXIF in it, and its versions are not the ones the site asks for.
RSpec.describe 'after_party:recompress_post_covers on stored originals' do
  include_context 'when carrierwave cleanup'

  let(:task) { 'after_party:recompress_post_covers' }
  let(:recorded) { AfterParty::TaskRecord.where(version: '20260824180000') }

  let(:scratch) { Pathname(Dir.mktmpdir('recompress', Rails.root.join('tmp'))) }

  after { FileUtils.rm_rf(scratch) }

  before { skip 'ImageMagick is not installed' unless MiniMagick::Utilities.which('magick') || MiniMagick::Utilities.which('convert') }

  def phone_post(orientation: 1)
    source = scratch.join('phone.jpg')
    ImageFixtures.jpeg_with_exif(source, width: 2400, height: 1600, orientation: orientation)
    create(:post, photo: Rack::Test::UploadedFile.new(source, 'image/jpeg'))
  end

  def processing
    PhotoUploader.enable_processing = true
    yield
  ensure
    PhotoUploader.enable_processing = false
  end

  def exposed?(path) = File.binread(path).include?(ImageFixtures::CAMERA_MAKE)

  it 'strips the original in place and cuts the two versions from it' do
    post = phone_post(orientation: 6)
    expect(exposed?(post.photo.path)).to be(true)

    run = processing { run_task(task) }

    photo = post.reload.photo
    expect(run.stdout).to include('rebuilt: 1')
    expect(exposed?(photo.path)).to be(false)
    expect(MiniMagick::Image.new(photo.path).dimensions).to eq([1600, 2400])
    [photo.medium.path, photo.small.path].each do |path|
      expect(exposed?(path)).to be(false)
      expect(MiniMagick::Image.new(path)['%Q']).to eq('80')
    end
    expect(MiniMagick::Image.new(photo.medium.path).dimensions).to eq(PhotoUploader::MEDIUM)
    expect(recorded.count).to eq(1)
  end

  it 'names a cover it cannot read, rebuilds the rest and still records itself' do
    broken = create(:post)
    File.write(broken.photo.path, 'not an image')
    healthy = phone_post

    run = processing { run_task(task) }

    expect(run.stdout).to include('rebuilt: 1', 'failed: 1')
    expect(run.stderr).to include("post ##{broken.id}", "covers:rebuild IDS=#{broken.id}")
    expect(run).not_to be_aborted
    expect(exposed?(healthy.reload.photo.path)).to be(false)
    expect(recorded.count).to eq(1)
  end

  it 'does not re-encode an original it has already normalised' do
    post = phone_post(orientation: 6)
    processing { run_task(task) }
    recorded.delete_all
    path = post.reload.photo.path
    before = [File.binread(path), File.mtime(path)]

    processing { run_task(task) }

    expect([File.binread(path), File.mtime(path)]).to eq(before)
  end

  it 'reports a cover whose file is gone without holding the deploy' do
    gone = create(:post)
    FileUtils.rm_f(gone.photo.path)

    run = processing { run_task(task) }

    expect(run.stderr).to include("post ##{gone.id}")
    expect(run.stdout).to include('file missing: 1', 'failed: 0')
    expect(run).not_to be_aborted
    expect(recorded.count).to eq(1)
  end

  # The release still serving during the deploy asks for exactly these files.
  it 'leaves the versions the old uploader wrote where they are' do
    post = phone_post
    directory = File.dirname(post.photo.path)
    legacy = %w[lite_x.jpg thumb_x.png large_x.png medium_x.png small_x.png].map { |name| File.join(directory, name) }
    legacy.each { |path| FileUtils.cp(post.photo.path, path) }

    processing { run_task(task) }

    expect(legacy.all? { |path| File.exist?(path) }).to be(true)
    photo = post.reload.photo
    expect([photo.medium.path, photo.small.path].all? { |path| File.exist?(path) }).to be(true)
  end

  it 'records itself when the only posts it skipped are ones with no cover' do
    create(:post).update_columns(photo: nil)

    run = processing { run_task(task) }

    expect(run.stdout).to include('failed: 0')
    expect(recorded.count).to eq(1)
  end
end
