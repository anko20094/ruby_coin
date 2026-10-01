# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'team:check' do # rubocop:disable RSpec/DescribeClass
  include_context 'when the cases are imported'
  include_context 'when the cv is imported'

  it 'prints the notes and says the roster is consistent' do
    run = run_task('team:check')

    expect(run.aborted?).to be(false)
    expect(run.stdout).to include('note: 1 placeholder CV', 'roster is consistent')
  end

  it 'prints every problem, counts them and exits non-zero' do
    result = Team::Check::Result.new(problems: ['  ana has no role', '  bo has no period'], notes: [])
    allow(Team::Check).to receive(:call).and_return(result)

    run = run_task('team:check')

    expect(run.exit_status).to eq(1)
    expect(run.stderr).to include('ana has no role', 'bo has no period', '2 problems.')
  end
end
