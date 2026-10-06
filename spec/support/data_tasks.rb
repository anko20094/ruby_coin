# frozen_string_literal: true

require 'rake'

module DataTasks
  Run = Struct.new(:stdout, :stderr, :exit_status) do
    def aborted? = !exit_status.nil?
  end

  def self.load!
    Rails.application.load_tasks unless Rake::Task.task_defined?('after_party:run')
  end

  def run_task(name)
    DataTasks.load!
    Rake::Task.tasks.select { |task| task.name.match?(/\A(after_party|cleanup|covers|team):/) }.each(&:reenable)

    capture { Rake::Task[name].invoke }
  end

  # Output and the exit of `abort` are returned rather than expected, so one example can look at
  # what a failing task printed, what it left behind and whether it said it was done.
  def capture
    stdout = StringIO.new
    stderr = StringIO.new
    connection = ActiveRecord::Base.connection
    depth = connection.open_transactions
    original = [$stdout, $stderr]
    $stdout = stdout
    $stderr = stderr
    status = nil

    begin
      yield
    rescue SystemExit => e
      status = e.status
    ensure
      $stdout, $stderr = original
      # What the exit of a real process does to a transaction an aborted task left open.
      connection.rollback_transaction while connection.open_transactions > depth
    end

    Run.new(stdout.string, stderr.string, status)
  end

  # Cumulative within an example: a later call overrides one name and keeps the others.
  def with_env(**variables)
    @env_overrides = (@env_overrides || {}).merge(variables.transform_keys(&:to_s))

    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:fetch).and_call_original
    @env_overrides.each do |name, value|
      allow(ENV).to receive(:[]).with(name).and_return(value)
      allow(ENV).to receive(:fetch).with(name, anything) { |_, default| value.nil? ? default : value }
    end
  end
end

RSpec.configure do |config|
  config.include DataTasks, file_path: %r{spec/tasks/}
end
