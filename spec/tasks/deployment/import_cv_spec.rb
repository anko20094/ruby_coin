# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'the CV deployment tasks' do
  describe 'after_party:import_cv' do
    it 'loads the CV and records itself' do
      run = run_task('after_party:import_cv')

      expect(run.stdout).to include('every field matches the yaml')
      expect(CVProfile.count).to eq(1)
      expect(AfterParty::TaskRecord.where(version: '20260822141500').count).to eq(1)
    end
  end

  describe 'after_party:reimport_cv' do
    it 'copies the yaml over a CV that has drifted from it, and records itself' do
      CV::Importer.call
      CVProfile.current.update_columns(strengths: [])

      run_task('after_party:reimport_cv')

      expect(CVProfile.current.strengths.size).to eq(4)
      expect(AfterParty::TaskRecord.where(version: '20260910120000').count).to eq(1)
    end
  end
end
