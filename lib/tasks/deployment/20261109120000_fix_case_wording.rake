# frozen_string_literal: true

# WRD-1600: the cases' copy as reviewed — wording slips in both languages, the studio's voice ("we"
# where it read as one person's CV), the learning-hub framing taken off the RubyCoin case, and a few
# figures dated. The table is the source of truth, so the fix is made where it lives.
#
# The YAML beside this file holds, per case and column, the value the table was imported with and
# the value it should hold now: config/portfolio/cases.yml as of 407490d (what production imported)
# against the file in this commit, column by column. A column is replaced only while it still holds the
# imported value: one the admin has edited since is left alone and named in the output, for a person
# to merge by hand. A second run finds nothing to do.
namespace :after_party do
  desc 'Deployment task: fix_case_wording'
  task fix_case_wording: :environment do
    changes = YAML.load_file(File.join(__dir__, '20261109120000_fix_case_wording.yml'))
    # Through the model's own types, so a value compares the way it is stored.
    typed = ->(column, value) { Case.new(column => value)[column] }
    fixed = []
    edited = []

    changes.each do |slug, columns|
      kase = Case.find_by(slug: slug) or next
      updates = columns.each_with_object({}) do |(column, change), found|
        next if kase[column] == typed.call(column, change['to'])

        if kase[column] == typed.call(column, change['from'])
          found[column] = typed.call(column, change['to'])
        else
          edited << "#{slug}.#{column}"
        end
      end
      next if updates.empty?

      kase.update_columns(updates.merge(updated_at: Time.current))
      fixed << slug
    end

    puts "case wording fixed in: #{fixed.presence&.join(', ') || 'none'}"
    puts "edited in the admin since the import, left for a person: #{edited.join(', ')}" if edited.any?
    AfterParty::TaskRecord.create(version: AfterParty::TaskRecorder.new(__FILE__).timestamp)
  end
end
