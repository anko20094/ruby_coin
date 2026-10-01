# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'the cases deployment tasks' do
  let(:mismatch) do
    Cases::Importer::Result.new(imported: [], mismatches: ['dna.mark: expected 2, stored "2"'], strays: [])
  end

  describe 'after_party:import_cases' do
    let(:task) { 'after_party:import_cases' }

    it 'loads the seven cases and records itself' do
      run = run_task(task)

      expect(run.stdout).to include('cases imported: 7', 'every field matches the yaml')
      expect(Case.count).to eq(7)
      expect(AfterParty::TaskRecord.where(version: '20260822131500').count).to eq(1)
    end

    it 'names a case the yaml does not have, which a renamed slug leaves behind' do
      run_task(task)
      Case.find_by!(slug: 'dna').update_columns(slug: 'dna-renamed')

      run = run_task(task)

      expect(run.stdout).to include('in the table, not in the yaml: dna-renamed')
    end

    it 'refuses to record itself when the copy does not match, and says what differs' do
      allow(Cases::Importer).to receive(:call).and_return(mismatch)

      run = run_task(task)

      expect(run.exit_status).to eq(1)
      expect(run.stderr).to include('the copy does not match the source', 'dna.mark')
      expect(AfterParty::TaskRecord.where(version: '20260822131500')).to be_empty
    end
  end

  describe 'after_party:reimport_cases' do
    let(:task) { 'after_party:reimport_cases' }

    it 'puts the yaml back over a case edited in the admin' do
      Cases::Importer.call
      Case.find_by!(slug: 'dna').update_columns(title: { 'en' => 'EDITED IN ADMIN', 'uk' => 'ПРАВЛЕНО' })

      run_task(task)

      expect(Case.find_by!(slug: 'dna')[:title]['en']).not_to eq('EDITED IN ADMIN')
    end

    it 'records itself once the copy matches' do
      run = run_task(task)

      expect(run.stdout).to include('cases: 7 imported', 'every field matches the yaml')
      expect(AfterParty::TaskRecord.where(version: '20260913091000').count).to eq(1)
    end

    it 'refuses to record itself when the copy does not match' do
      allow(Cases::Importer).to receive(:call).and_return(mismatch)

      run = run_task(task)

      expect(run.exit_status).to eq(1)
      expect(AfterParty::TaskRecord.where(version: '20260913091000')).to be_empty
    end
  end
end
