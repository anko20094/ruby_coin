# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'cover tasks' do # rubocop:disable RSpec/DescribeClass
  include_context 'when carrierwave cleanup'

  let(:post) { create(:post) }
  let(:directory) { File.dirname(post.photo.path) }
  let(:legacy) do
    %w[lite_x.jpg thumb_x.png large_x.png medium_x.png small_x.png].map { |name| File.join(directory, name) }
  end

  def current_files(post) = [post.photo, post.photo.medium, post.photo.small].map(&:path)

  describe 'covers:rebuild' do
    it 'rebuilds only the posts named in IDS' do
      other = create(:post)
      [post, other].each { |record| FileUtils.rm_f(record.photo.medium.path) }
      with_env(IDS: post.id.to_s)

      run = run_task('covers:rebuild')

      expect(run.stdout).to include('covers rebuilt: 1', 'failed: 0')
      expect(File).to exist(post.reload.photo.medium.path)
      expect(File).not_to exist(other.reload.photo.medium.path)
    end

    it 'exits non-zero and names a post that still fails' do
      allow_any_instance_of(PhotoUploader).to receive(:recreate_versions!)
        .and_raise(CarrierWave::ProcessingError, 'boom')
      with_env(IDS: post.id.to_s)

      run = run_task('covers:rebuild')

      expect(run).to be_aborted
      expect(run.stderr).to include("posts #{post.id}")
    end
  end

  describe 'cleanup:legacy_cover_versions' do
    before { legacy.each { |path| FileUtils.cp(post.photo.path, path) } }

    it 'only lists the old versions by default' do
      run = run_task('cleanup:legacy_cover_versions')

      expect(run.stdout).to include('would delete 5 legacy cover versions', '[dry run]')
      expect(legacy.all? { |path| File.exist?(path) }).to be(true)
    end

    it 'deletes the old versions and keeps the original and the current ones under DRY_RUN=0' do
      with_env(DRY_RUN: '0')

      run = run_task('cleanup:legacy_cover_versions')

      expect(run.stdout).to include('deleted 5 legacy cover versions')
      expect(legacy.none? { |path| File.exist?(path) }).to be(true)
      expect(current_files(post.reload).all? { |path| File.exist?(path) }).to be(true)
    end

    it 'leaves a cover alone while its current versions are missing' do
      FileUtils.rm_f(post.photo.small.path)
      with_env(DRY_RUN: '0')

      run_task('cleanup:legacy_cover_versions')

      expect(legacy.all? { |path| File.exist?(path) }).to be(true)
    end
  end
end
