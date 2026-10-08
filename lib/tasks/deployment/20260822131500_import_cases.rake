# frozen_string_literal: true

# Loads the cases config/portfolio/cases.yml has and the table does not. A case already in the
# table is the admin's and is kept; FORCE=1 puts the YAML back over every one of them.
namespace :after_party do
  desc 'Deployment task: import_cases'
  task import_cases: :environment do
    result = Cases::Importer.call(force: ENV['FORCE'].present?)

    puts "cases imported: #{result.imported.size}, kept: #{result.kept.size}, table now holds: #{Case.count}"
    puts "order: #{Case.ordered.pluck(:mark, :slug).map { |mark, slug| "#{mark} #{slug}" }.join(', ')}"
    puts "in the table, not in the yaml: #{result.strays.join(', ')}" if result.strays.any?

    abort "the copy does not match the source:\n  #{result.mismatches.join("\n  ")}" unless result.ok?

    puts 'every field matches the yaml'
    AfterParty::TaskRecord.create(version: AfterParty::TaskRecorder.new(__FILE__).timestamp)
  end
end
