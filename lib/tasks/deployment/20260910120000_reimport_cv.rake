# frozen_string_literal: true

# cv.yml changed after the first import had already run everywhere, so this deploy copies the
# new text in. `execute` rather than `invoke`: on a fresh database import_cv has just run the
# same task in this process, and invoke would skip it.
namespace :after_party do
  desc 'Deployment task: reimport_cv'
  task reimport_cv: :environment do
    Rake::Task['cv:import'].execute

    AfterParty::TaskRecord.create(version: AfterParty::TaskRecorder.new(__FILE__).timestamp)
  end
end
