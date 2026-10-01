# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'cv:import' do # rubocop:disable RSpec/DescribeClass
  it 'copies the yaml into the CV row and says the copy matches' do
    run = run_task('cv:import')

    expect(run.stdout).to include('4 experience, 2 stack_groups, 4 strengths', 'every field matches the yaml')
    expect(run.aborted?).to be(false)
  end

  it 'can be run again without adding a second row' do
    run_task('cv:import')

    expect { run_task('cv:import') }.not_to change(CVProfile, :count)
  end

  it 'exits non-zero, and prints what differs, when the copy does not match' do
    profile = CVProfile.new(name: { 'en' => 'Someone', 'uk' => 'Хтось' })
    result = CV::Importer::Result.new(profile: profile, mismatches: ['profile.figures_as_of: expected 2026'])
    allow(CV::Importer).to receive(:call).and_return(result)

    run = run_task('cv:import')

    expect(run.exit_status).to eq(1)
    expect(run.stderr).to include('the copy does not match the source', 'profile.figures_as_of')
  end
end
