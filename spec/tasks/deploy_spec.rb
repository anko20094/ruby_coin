# frozen_string_literal: true

require 'open3'
require 'rails_helper'

# A dry run prints every task Capistrano would execute, in order, without connecting anywhere.
RSpec.describe 'cap production deploy' do # rubocop:disable RSpec/DescribeClass
  let(:dry_run) do
    output, = Open3.capture2e('bundle', 'exec', 'cap', 'production', 'deploy', '--dry-run', '--trace',
                              chdir: Rails.root.to_s)
    output
  end
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

  it 'runs the pending tasks and then the CV import' do
    expect(dry_run).to match(/rake after_party:run.*rake cv:import/m)
  end

  it 'leaves the data tasks out of any run that is not a deploy, such as a rollback' do
    output, = Open3.capture2e('bundle', 'exec', 'cap', 'production', 'deploy:data', '--dry-run', chdir: Rails.root.to_s)

    expect(output).not_to include('after_party:run')
  end
end
