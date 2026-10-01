# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CVProfile do
  include_context 'when the cv is imported'

  describe '.current' do
    it 'returns the one row there is' do
      expect(described_class.current).to eq(described_class.first)
    end

    it 'hands back an unsaved row on an empty table, so the page still renders' do
      described_class.delete_all

      expect(described_class.current).to be_new_record
      expect(described_class.current.name).to be_nil
    end
  end

  describe '.current, asked again in the same request' do
    def cv_queries(&)
      statements = []
      collect = ->(*, payload) { statements << payload[:sql] if payload[:sql].include?('FROM "cv_profiles"') }

      ActiveSupport::Notifications.subscribed(collect, 'sql.active_record', &)
      statements.size
    end

    it 'reads the row once, however many callers ask' do
      expect(cv_queries { 4.times { described_class.current } }).to eq(1)
    end

    it 'is the same row the owner on the roster reads' do
      expect(Team.owner.cv).to equal(described_class.current)
    end

    it 'remembers that the table is empty rather than asking again' do
      described_class.delete_all

      expect(cv_queries { 3.times { described_class.current } }).to eq(1)
    end

    it 'reads again in the next request' do
      expect(described_class.current.location).to be_present

      described_class.first.update_columns(location: { 'en' => 'Elsewhere', 'uk' => 'Деінде' })
      Current.reset

      expect(I18n.with_locale(:en) { described_class.current.location }).to eq('Elsewhere')
    end

    it 'forgets the row when a row is saved, so the importer is never read back stale' do
      described_class.current.update_columns(strengths: [])

      CV::Importer.call

      expect(described_class.current.strengths).to be_present
    end
  end

  describe 'localised scalars' do
    it 'returns the current locale' do
      I18n.with_locale(:en) { expect(described_class.current.name).to eq('Danyil Shkoropad') }
      I18n.with_locale(:uk) { expect(described_class.current.name).to eq('Даниїл Шкоропад') }
    end

    it 'refuses a scalar written in one language only' do
      profile = described_class.current
      profile.summary = { 'en' => 'only english' }

      expect(profile).not_to be_valid
      expect(profile.errors.attribute_names).to include(:summary)
    end
  end

  describe 'contact rows' do
    it 'keeps key, label and href in the order they are printed' do
      expect(described_class.current.contact_rows.first).to eq(%w[email anko20094@gmail.com mailto:anko20094@gmail.com])
    end
  end

  # The career, the stack groups and the strengths. They were a cv_blocks table with a model,
  # a controller and CRUD screens, which made a ten-line document behave like a collection you
  # browse; they are StructuredJson fields on this row now. See redesign_plan.md §12.
  describe 'the three lists' do
    it 'reads a row as a ready-to-print hash in the current locale' do
      entry = I18n.with_locale(:en) { described_class.current.experience.first }

      expect(entry[:org]).to eq('myHomeIQ')
      expect(entry[:title]).to include('Senior Backend Engineer')
      expect(entry[:case_slugs]).to eq(%w[intelligence leads])
    end

    # A proper noun is written once in the YAML rather than as a pair, and reads the same in
    # both languages.
    it 'lets a plain string stand for both languages' do
      %i[en uk].each do |locale|
        expect(I18n.with_locale(locale) { described_class.current.experience.first[:org] }).to eq('myHomeIQ')
      end
    end

    it 'reads a strength as the string it is, not a hash of one' do
      expect(I18n.with_locale(:en) { described_class.current.strengths.first }).to be_a(String)
    end
  end
end
