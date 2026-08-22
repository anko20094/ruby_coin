# frozen_string_literal: true

# Loads the CV frame from config/portfolio/cv.yml into cv_profiles and cv_blocks.
namespace :after_party do
  desc 'Deployment task: import_cv'
  task import_cv: :environment do
    result = CV::Importer.call

    puts "profile: #{result.profile.name_en.inspect}, blocks: #{result.blocks.size} " \
         "(#{CVBlock.group(:kind).count.map { |kind, count| "#{kind} #{count}" }.join(', ')})"

    abort "the copy does not match the source:\n  #{result.mismatches.join("\n  ")}" unless result.clean?

    puts 'every field matches the yaml'
    AfterParty::TaskRecord.create(version: AfterParty::TaskRecorder.new(__FILE__).timestamp)
  end
end
