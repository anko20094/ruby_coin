# frozen_string_literal: true

# `year`, `sector`, `status` and every figure became language pairs, so the rows have to be
# rewritten from the file that holds the Ukrainian text. The migration filled the three new
# columns with the old English string in both languages; this is what replaces it.
#
# It overwrites anything edited in /management/cases since the first import. That is the point
# on this deploy — the columns it rewrites did not exist in their current shape before it — and
# it is why this is a one-off task rather than a recurring one.
namespace :after_party do
  desc 'Deployment task: reimport_cases'
  task reimport_cases: :environment do
    result = Cases::Importer.call

    puts "cases: #{result.imported.size} imported"
    abort "the copy does not match the source:\n  #{result.mismatches.join("\n  ")}" unless result.clean?

    puts 'every field matches the yaml'
    AfterParty::TaskRecord.create(version: AfterParty::TaskRecorder.new(__FILE__).timestamp)
  end
end
