# frozen_string_literal: true

# Post covers on disk (Posts::Covers). Neither task is part of a deploy.
namespace :covers do
  # IDS=3,7 for those posts, every post without it. Non-zero if any of them still fails.
  desc 'Rebuild post covers: normalise the original if needed and cut the current versions'
  task rebuild: :environment do
    result = Posts::Covers.rebuild(Posts::Covers.scope(ENV.fetch('IDS', nil)))

    puts "covers rebuilt: #{result.rebuilt}, without a cover: #{result.without_cover}, " \
         "file missing: #{result.missing.size}, failed: #{result.failed.size}"
    abort "covers not rebuilt: posts #{result.failed.keys.join(',')}" if result.failed.any?
  end
end

namespace :cleanup do
  # The old uploader's versions (lite_, thumb_, large_, the .png medium_/small_) carry the
  # camera's EXIF and nothing reads them once the new release serves. Run it after that deploy,
  # not during it: the release being replaced still asks for them. Prints what it would delete
  # unless DRY_RUN=0. A cover whose current versions are missing is left alone.
  desc 'Delete the version files the old cover uploader left beside each original'
  task legacy_cover_versions: :environment do
    dry_run = ENV.fetch('DRY_RUN', '1') != '0'
    verb = dry_run ? 'would delete' : 'deleted'
    count = 0

    Posts::Covers.scope(ENV.fetch('IDS', nil)).find_each do |post|
      Posts::Covers.legacy_versions(post).each do |path|
        FileUtils.rm_f(path) unless dry_run
        puts "  #{verb} #{Pathname(path).relative_path_from(Rails.public_path)}"
        count += 1
      end
    end

    puts "#{verb} #{count} legacy cover versions"
    puts '[dry run] nothing was deleted; DRY_RUN=0 to delete' if dry_run
  end
end
