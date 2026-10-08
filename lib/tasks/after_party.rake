# frozen_string_literal: true

# DRY_RUN=1 bin/rails after_party:run runs every pending task for real inside one transaction
# and rolls it back; a task that writes outside the database checks DRY_RUN itself.
namespace :after_party do
  task rehearse: :environment do
    next if ENV['DRY_RUN'].blank?

    ActiveRecord::Base.connection.begin_transaction(joinable: false)
    puts '[dry run] every task below runs in a transaction that is rolled back'
  end

  Rake::Task['after_party:run'].enhance(['after_party:rehearse']) do
    next if ENV['DRY_RUN'].blank?

    ActiveRecord::Base.connection.rollback_transaction
    puts '[dry run] rolled back: nothing was written and no task was recorded'
  end
end
