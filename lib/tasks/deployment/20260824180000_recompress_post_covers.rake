# frozen_string_literal: true

# PhotoUploader stopped converting covers to PNG and now writes JPEG at quality 80, and the
# three versions nothing read (lite, thumb, large) are gone. Existing covers were stored as
# `medium_<name>.png`, so `photo.medium.url` points at a filename the new uploader would spell
# `.jpg` — every cover on the site would 404 until the files are rebuilt.
#
# This is that rebuild. It is idempotent and safe to run twice.
namespace :after_party do
  desc 'Deployment task: recompress_post_covers'
  task recompress_post_covers: :environment do
    rebuilt = 0
    skipped = 0

    Post.find_each do |post|
      next skipped += 1 if post.photo.blank? || post.photo.file.blank?

      post.photo.recreate_versions!(:medium, :small)
      rebuilt += 1
    rescue CarrierWave::ProcessingError, Errno::ENOENT => e
      warn "  post ##{post.id} (#{post.slug}): #{e.class} — #{e.message}"
      skipped += 1
    end

    puts "covers rebuilt: #{rebuilt}, skipped: #{skipped}"

    AfterParty::TaskRecord.create(version: AfterParty::TaskRecorder.new(__FILE__).timestamp)
  end
end
