# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('db', 'migrate', '20260825120000_fold_cv_blocks_into_the_profile')

RSpec.describe FoldCVBlocksIntoTheProfile do
  let(:connection) { ActiveRecord::Base.connection }

  def migrate(direction)
    ActiveRecord::Migration.suppress_messages { described_class.new.migrate(direction) }
  end

  def block(kind, position, payload, case_slugs = [])
    connection.execute(
      'INSERT INTO cv_blocks (kind, position, payload, case_slugs, created_at, updated_at) VALUES ' \
      "(#{connection.quote(kind)}, #{position}, #{connection.quote(payload.to_json)}, " \
      "#{connection.quote(case_slugs.to_json)}, now(), now())"
    )
  end

  def profile
    row = connection.select_one('SELECT experience, stack_groups, strengths FROM cv_profiles')
    row.transform_values { |json| JSON.parse(json) }
  end

  before do
    migrate(:down)
    described_class::Profile.reset_column_information
  end

  after do
    described_class::Profile.reset_column_information
    CVProfile.reset_column_information
  end

  context 'when the database has a profile and its blocks' do
    before do
      connection.execute('INSERT INTO cv_profiles (created_at, updated_at) VALUES (now(), now())')
      block('experience', 2, { org: 'Second', title: 'Lead', note: 'x', unrelated: 'dropped' }, %w[dna])
      block('experience', 1, { org: 'First', title: 'Engineer', place: 'Kyiv', period: '2020' },
            %w[intelligence leads])
      block('stack_group', 1, { label: { en: 'Backend', uk: 'Бекенд' }, items: %w[Ruby PostgreSQL], unrelated: 1 })
      block('strength', 1, { text: { en: 'Reads the data first', uk: 'Спершу читає дані' } })
      migrate(:up)
    end

    it 'puts the career entries on the profile in position order, with their case links' do
      expect(profile['experience']).to eq(
        [
          {
            'org' => 'First', 'title' => 'Engineer', 'place' => 'Kyiv', 'period' => '2020',
            'case_slugs' => %w[intelligence leads]
          },
          { 'org' => 'Second', 'title' => 'Lead', 'note' => 'x', 'case_slugs' => %w[dna] }
        ]
      )
    end

    it 'keeps the label and items of a stack group and nothing else' do
      expect(profile['stack_groups']).to eq(
        [{ 'label' => { 'en' => 'Backend', 'uk' => 'Бекенд' }, 'items' => %w[Ruby PostgreSQL] }]
      )
    end

    it 'unwraps a strength to the language pair it is' do
      expect(profile['strengths']).to eq([{ 'en' => 'Reads the data first', 'uk' => 'Спершу читає дані' }])
    end

    it 'leaves the blocks table where it was, until a copy of production has been checked' do
      expect(connection.select_value('SELECT count(*) FROM cv_blocks')).to eq(4)
    end
  end

  context 'when there is no profile yet' do
    it 'adds the columns and has nothing to copy' do
      expect { migrate(:up) }.not_to raise_error
      expect(connection.column_exists?(:cv_profiles, :experience)).to be(true)
    end
  end

  it 'removes the three columns again on the way down' do
    migrate(:up)
    migrate(:down)

    columns = %i[experience stack_groups strengths].map { |column| connection.column_exists?(:cv_profiles, column) }

    expect(columns).to all(be(false))
  end
end
