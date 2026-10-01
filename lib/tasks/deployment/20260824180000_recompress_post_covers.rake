# frozen_string_literal: true

# PhotoUploader now stores a stripped, upright original and cuts two JPEG versions from it.
# Existing covers were stored as `medium_<name>.png` beside an original that still carries the
# camera's EXIF, so `photo.medium.url` points at a filename the new uploader spells `.jpg` and
# the original is a public file with GPS in it.
#
# This normalises each original in place, rebuilds its two versions and removes the versions of
# the old uploader (lite_, thumb_, large_ and the .png medium_/small_), which carry the same EXIF.
# It is idempotent and safe to run twice. A cover that cannot be rebuilt stops the task with a
# non-zero status so the deploy does not go live on it; a cover whose file is gone is only
# reported. Under DRY_RUN it counts the covers and writes nothing.
namespace :after_party do
  desc 'Deployment task: recompress_post_covers'
  task recompress_post_covers: :environment do
    dry_run = ENV['DRY_RUN'].present?
    rebuilt = 0
    without_cover = 0
    failed = []
    missing = []

    Post.find_each do |post|
      next without_cover += 1 if post[:photo].blank?

      if post.photo.blank?
        warn "  post ##{post.id} (#{post.slug}): the file #{post[:photo]} is missing"
        next missing << post.id
      end

      unless dry_run
        post.photo.normalize
        post.photo.recreate_versions!(:medium, :small)
        keep = [post.photo, post.photo.medium, post.photo.small].map(&:path)
        Dir[File.join(File.dirname(post.photo.path), '*')].each { |path| FileUtils.rm_f(path) unless keep.include?(path) }
      end
      rebuilt += 1
    rescue CarrierWave::ProcessingError, CarrierWave::IntegrityError, ImageProcessing::Error => e
      warn "  post ##{post.id} (#{post.slug}): #{e.class} — #{e.message}"
      failed << post.id
    end

    puts "covers #{'that would be ' if dry_run}rebuilt: #{rebuilt}, without a cover: #{without_cover}, " \
         "file missing: #{missing.size}, failed: #{failed.size}"

    abort "covers not rebuilt, task left pending: posts #{failed.join(', ')}" if failed.any?

    AfterParty::TaskRecord.create(version: AfterParty::TaskRecorder.new(__FILE__).timestamp) unless dry_run
  end
end
