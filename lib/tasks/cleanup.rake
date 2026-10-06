# frozen_string_literal: true

namespace :cleanup do
  # Prints what it would delete unless DRY_RUN=0. DAYS sets how old an orphan must be (7).
  desc 'Delete journal blocks and editor images no stored body refers to'
  task editor_orphans: :environment do
    dry_run = ENV.fetch('DRY_RUN', '1') != '0'
    days = Integer(ENV.fetch('DAYS', '7'))

    result = Editor::Orphans.call(older_than: days.days, delete: !dry_run)
    verb = dry_run ? 'would delete' : 'deleted'

    puts "#{verb} #{result.blocks.size} journal blocks older than #{days} days: #{result.blocks.join(', ')}"
    puts "#{verb} #{result.blobs.size} editor images older than #{days} days: #{result.blobs.join(', ')}"
    puts '[dry run] nothing was deleted; DRY_RUN=0 to delete' if dry_run
  end
end
