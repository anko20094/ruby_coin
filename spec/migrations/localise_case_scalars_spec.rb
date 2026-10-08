# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('db', 'migrate', '20260913090000_localise_case_scalars')

RSpec.describe LocaliseCaseScalars do
  let(:connection) { ActiveRecord::Base.connection }

  def migrate(direction)
    ActiveRecord::Migration.suppress_messages { described_class.new.migrate(direction) }
  end

  def insert_case(slug, **columns)
    values = { slug: slug, mark: '01', position: 1, created_at: Time.current, updated_at: Time.current }.merge(columns)
    quoted = values.values.map { |value| connection.quote(value) }
    connection.execute("INSERT INTO cases (#{values.keys.join(', ')}) VALUES (#{quoted.join(', ')})")
  end

  def stored(slug, column)
    connection.select_value("SELECT #{column} FROM cases WHERE slug = #{connection.quote(slug)}")
  end

  after { Case.reset_column_information }

  describe 'up' do
    before { migrate(:down) }

    it 'copies the one string into both languages, so nothing renders blank before the import' do
      insert_case('dna', year: '2022—present', sector: 'publishing · education', status: 'live')

      migrate(:up)

      expect(JSON.parse(stored('dna', 'year'))).to eq({ 'en' => '2022—present', 'uk' => '2022—present' })
      expect(JSON.parse(stored('dna', 'sector'))).to eq(
        { 'en' => 'publishing · education', 'uk' => 'publishing · education' }
      )
      expect(JSON.parse(stored('dna', 'status'))).to eq({ 'en' => 'live', 'uk' => 'live' })
    end

    it 'turns a missing value into two empty strings rather than a null pair' do
      insert_case('leads')

      migrate(:up)

      expect(JSON.parse(stored('leads', 'status'))).to eq({ 'en' => '', 'uk' => '' })
    end

    it 'leaves the columns it did not touch alone' do
      insert_case('dna', year: '2022', title: { en: 'DNA', uk: 'ДНК' }.to_json)

      migrate(:up)

      expect(JSON.parse(stored('dna', 'title'))).to eq({ 'en' => 'DNA', 'uk' => 'ДНК' })
    end
  end

  describe 'down' do
    it 'keeps the English string only, which is all a single-language column can hold' do
      insert_case('dna', year: { en: '2022—present', uk: '2022—донині' }.to_json,
                         sector: { en: 'publishing', uk: 'видавництво' }.to_json,
                         status: { en: 'live', uk: 'працює' }.to_json)

      migrate(:down)

      expect(stored('dna', 'year')).to eq('2022—present')
      expect(stored('dna', 'sector')).to eq('publishing')
      expect(stored('dna', 'status')).to eq('live')
    end

    it 'round-trips back to a pair that carries the English text twice' do
      insert_case('dna', year: { en: '2022', uk: '2022 р.' }.to_json)

      migrate(:down)
      migrate(:up)

      expect(JSON.parse(stored('dna', 'year'))).to eq({ 'en' => '2022', 'uk' => '2022' })
    end
  end
end
