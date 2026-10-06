# frozen_string_literal: true

module JobQueue
  def queue_adapter_for_test = ActiveJob::QueueAdapters::TestAdapter.new
end

RSpec.configure do |config|
  config.include ActiveJob::TestHelper, :jobs
  config.include JobQueue, :jobs
end
