# frozen_string_literal: true

# Loads the seven cases from config/portfolio/cases.yml into the cases table. Idempotent:
# matches on slug, so running it twice does not duplicate anything.
namespace :after_party do
  desc 'Deployment task: import_cases'
  task import_cases: :environment do
    result = Cases::Importer.call

    puts "cases imported: #{result.imported.size}, table now holds: #{Case.count}"
    puts "order: #{Case.ordered.pluck(:mark, :slug).map { |mark, slug| "#{mark} #{slug}" }.join(', ')}"
    puts "in the table, not in the yaml: #{result.strays.join(', ')}" if result.strays.any?

    abort "the copy does not match the source:\n  #{result.mismatches.join("\n  ")}" unless result.clean?

    puts 'every field matches the yaml'
    AfterParty::TaskRecord.create(version: AfterParty::TaskRecorder.new(__FILE__).timestamp)
  end
end
