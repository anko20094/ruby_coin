# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'after_party:fix_case_wording' do
  let(:task) { 'after_party:fix_case_wording' }
  let(:changes) { YAML.load_file(Rails.root.join('lib', 'tasks', 'deployment', '20261109120000_fix_case_wording.yml')) }

  def typed(column, value) = Case.new(column => value)[column]

  # The yaml as the importer stores it, column by column.
  def source
    importer = Cases::Importer.new
    YAML.load_file(Cases::Importer::SOURCE)['cases'].each_with_index.to_h do |entry, index|
      [entry['slug'], importer.__send__(:attributes_for, entry, index).transform_keys(&:to_s)]
    end
  end

  # The table as production holds it: every changed column still at its imported value.
  before do
    Cases::Importer.call(force: false)
    changes.each do |slug, columns|
      Case.find_by!(slug: slug).update_columns(columns.to_h do |column, change|
        [column, typed(column, change['from'])]
      end)
    end
  end

  it 'agrees with cases.yml: every target is what the yaml now says' do
    changes.each do |slug, columns|
      columns.each do |column, change|
        expect(typed(column, change['to'])).to eq(typed(column, source.dig(slug, column))), "#{slug}.#{column}"
      end
    end
  end

  it 'brings every changed column to the yaml, and records itself' do
    run = run_task(task)

    expect(run.stdout).to include('case wording fixed in:')
    changes.each do |slug, columns|
      kase = Case.find_by!(slug: slug)
      columns.each_key do |column|
        expect(kase[column]).to eq(typed(column, source.dig(slug, column))), "#{slug}.#{column}"
      end
    end
    expect(AfterParty::TaskRecord.where(version: '20261109120000').count).to eq(1)
  end

  it 'leaves a column the admin has edited, names it, and finds nothing on a second pass' do
    # A column holding one { en:, uk: } pair, which the admin rewrote in English.
    slug, column = changes.flat_map { |s, columns| columns.keys.map { |c| [s, c] } }
                          .find { |s, c| typed(c, changes.dig(s, c, 'to')).is_a?(Hash) }
    edited = typed(column, changes.dig(slug, column, 'to')).merge('en' => 'Owner text.')
    Case.find_by!(slug: slug).update_columns(column => edited)

    run = run_task(task)

    expect(Case.find_by!(slug: slug)[column]).to eq(edited)
    expect(run.stdout).to include("left for a person: #{slug}.#{column}")

    AfterParty::TaskRecord.delete_all
    expect(run_task(task).stdout).to include('case wording fixed in: none')
  end
end
