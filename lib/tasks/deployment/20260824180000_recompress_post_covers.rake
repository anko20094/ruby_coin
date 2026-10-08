# frozen_string_literal: true

# PhotoUploader now stores a stripped, upright original and cuts two JPEG versions from it.
# Existing covers were stored as `medium_<name>.png` beside an original that still carries the
# camera's EXIF, so `photo.medium.url` points at a filename the new uploader spells `.jpg` and
# the original is a public file with GPS in it.
#
# This runs before the new release is live, while the old one still serves the old files, so it
# only adds: it strips each original that is not stripped yet (in place, same name) and writes
# the two new versions beside the old ones (Posts::Covers). It deletes nothing — the old
# versions go with `cleanup:legacy_cover_versions` once the new release serves.
#
# One unreadable cover does not hold the deploy: it is named, the task still records itself, and
# `bin/rails covers:rebuild IDS=…` retries just those. Running it twice re-encodes nothing that is
# already normalised. Under DRY_RUN it counts the covers and writes nothing.
namespace :after_party do
  desc 'Deployment task: recompress_post_covers'
  task recompress_post_covers: :environment do
    dry_run = ENV['DRY_RUN'].present?
    result = Posts::Covers.rebuild(Post.all, write: !dry_run)

    puts "covers #{'that would be ' if dry_run}rebuilt: #{result.rebuilt}, without a cover: #{result.without_cover}, " \
         "file missing: #{result.missing.size}, failed: #{result.failed.size}"

    if result.failed.any?
      ids = result.failed.keys.join(',')
      warn "covers not rebuilt: posts #{ids}; once the files are fixed: bin/rails covers:rebuild IDS=#{ids}"
    end

    AfterParty::TaskRecord.create(version: AfterParty::TaskRecorder.new(__FILE__).timestamp) unless dry_run
  end
end
