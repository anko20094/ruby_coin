# frozen_string_literal: true

# Seeds the CV on a database that has never had one. Changing the CV afterwards is `rake
# cv:import`, which can be run any number of times — see lib/tasks/cv.rake for why the CV has
# no admin screen.
namespace :after_party do
  desc 'Deployment task: import_cv'
  task import_cv: :environment do
    Rake::Task['cv:import'].invoke

    AfterParty::TaskRecord.create(version: AfterParty::TaskRecorder.new(__FILE__).timestamp)
  end
end
