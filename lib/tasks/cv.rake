# frozen_string_literal: true

# The CV lives in config/portfolio/cv.yml and this is how it gets into the database.
#
# There is no admin screen for it, by decision: the CV is ten short lines, changed a couple of
# times a year, and it is the one piece of content on this site where the history matters —
# what was claimed, and when. A git diff answers that and a JSONB column does not. See
# redesign_plan.md §12.5.
#
# Run it as often as you like. The importer rewrites the single row and then reads it back and
# compares, so a run that says nothing is wrong means the database and the file agree. The
# deploy runs it on every release (deploy:data), so a commit to cv.yml is the whole edit.
namespace :cv do
  desc 'Import config/portfolio/cv.yml into the CV row, and check the copy matches'
  task import: :environment do
    result = CV::Importer.call

    counts = CVProfile::STRUCTURES.keys.map { |field| "#{result.profile.public_send(field).size} #{field}" }
    puts "cv: #{result.profile.name_en.inspect} (#{counts.join(', ')})"

    abort "the copy does not match the source:\n  #{result.mismatches.join("\n  ")}" unless result.clean?

    puts 'every field matches the yaml'
  end
end
