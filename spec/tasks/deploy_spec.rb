# frozen_string_literal: true

require 'open3'
require 'rails_helper'

# A dry run prints every task Capistrano would execute, in order, without connecting anywhere.
RSpec.describe 'cap production deploy', :slow do # rubocop:disable RSpec/DescribeClass
  # One dry run for the whole file: every example reads the same output, and each run is a
  # Capistrano boot in a subprocess.
  runs = Hash.new do |memo, task|
    memo[task] = Open3.capture2e('bundle', 'exec', 'cap', 'production', task, '--dry-run', '--trace',
                                 chdir: Rails.root.to_s).first
  end
  define_method(:dry_run) { runs['deploy'] }
  let(:executed) { dry_run.scan(/^\*\* Execute (\S+)/).flatten }

  def position(task) = executed.index(task) || raise(ArgumentError, "#{task} did not run: #{executed.inspect}")

  it 'runs the data tasks on the new release after migrating and before the symlink moves' do
    expect(position('deploy:migrate')).to be < position('deploy:data')
    expect(position('deploy:data')).to be < position('deploy:publishing')
    expect(position('deploy:data')).to be < position('deploy:symlink:release')
  end

  it 'has finished the data before Puma restarts onto the new code' do
    expect(position('deploy:data')).to be < position('puma:smart_restart')
  end

  it 'does not run the data tasks again from the live release after the restart' do
    expect(executed).not_to include('after_party')
    expect(executed.count('deploy:data')).to eq(1)
  end

  it 'runs the pending tasks, and no CV import: the CV is read from cv.yml' do
    expect(dry_run).to include('rake after_party:run')
    expect(dry_run).not_to include('cv:import')
  end

  it 'leaves the data tasks out of any run that is not a deploy, such as a rollback' do
    output, = Open3.capture2e('bundle', 'exec', 'cap', 'production', 'deploy:data', '--dry-run', chdir: Rails.root.to_s)

    expect(output).not_to include('after_party:run')
  end
end
