# frozen_string_literal: true

# config/application.rb names :async for every environment, and ActiveJob::TestHelper leaves an
# adapter that is already configured alone. An example that looks at jobs asks for the test
# adapter with :jobs.
module JobQueue
  def queue_adapter_for_test = ActiveJob::QueueAdapters::TestAdapter.new
end

RSpec.configure do |config|
  config.include ActiveJob::TestHelper, :jobs
  config.include JobQueue, :jobs
end
