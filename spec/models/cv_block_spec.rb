# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CVBlock do
  include_context 'when the cv is imported'

  describe 'validations' do
    it 'rejects a kind it has no shape for' do
      expect(described_class.new(kind: 'hobby', position: 1)).not_to be_valid
    end

    it 'requires what each kind actually needs' do
      expect(described_class.new(kind: 'strength', position: 1)).not_to be_valid
      expect(described_class.new(kind: 'strength', position: 1, payload: { 'text' => { 'en' => 'x' } })).to be_valid
      expect(described_class.new(kind: 'stack_group', position: 1, payload: { 'label' => 'x' })).not_to be_valid
    end
  end

  describe 'scopes' do
    it 'splits the three kinds and orders each by position' do
      expect(described_class.experience.pluck(:position)).to eq([1, 2, 3, 4])
      expect(described_class.stack_groups.count).to eq(2)
      expect(described_class.strengths.count).to eq(4)
    end
  end

  describe 'payload readers' do
    let(:entry) { described_class.experience.first }

    it 'localises a field written as a language pair' do
      second = described_class.experience.second

      I18n.with_locale(:en) { expect(second.org).to eq('Own products') }
      I18n.with_locale(:uk) { expect(second.org).to eq('Власні продукти') }
    end

    # Employer names are proper nouns and the YAML writes them as one string.
    it 'passes a plain string through in both locales' do
      I18n.with_locale(:en) { expect(entry.org).to eq('myHomeIQ') }
      I18n.with_locale(:uk) { expect(entry.org).to eq('myHomeIQ') }
      expect([entry.org_en, entry.org_uk]).to eq(%w[myHomeIQ myHomeIQ])
    end

    it 'promotes a plain string to a pair on edit without losing the other language' do
      entry.org_uk = 'майХоумАйКю'

      expect(entry.payload['org']).to eq({ 'en' => 'myHomeIQ', 'uk' => 'майХоумАйКю' })
    end

    it 'reads nil for a key that belongs to another kind' do
      expect(described_class.strengths.first.period).to be_nil
    end

    it 'reads nil for an optional key the entry does not carry' do
      expect(described_class.experience.third.note).to be_nil
    end
  end

  describe 'list accessors' do
    it 'edits stack items one per line' do
      group = described_class.stack_groups.first
      group.items_list = "Rails\n  Postgres  \n\nSolid Queue"

      expect(group.items).to eq(['Rails', 'Postgres', 'Solid Queue'])
      expect(group.items_list).to eq("Rails\nPostgres\nSolid Queue")
    end

    it 'edits case slugs as a comma separated list' do
      entry = described_class.experience.first
      entry.case_slugs_list = 'dna, wardybot'

      expect(entry[:case_slugs]).to eq(%w[dna wardybot])
    end
  end

  describe '#cases' do
    include_context 'when the cases are imported'

    it 'returns the cases in the order the entry lists them' do
      entry = described_class.experience.first
      entry.update!(case_slugs: %w[leads intelligence])

      expect(entry.cases.map(&:slug)).to eq(%w[leads intelligence])
    end

    it 'skips a slug whose case has been deleted' do
      entry = described_class.experience.first
      entry.update!(case_slugs: %w[intelligence gone])

      expect(entry.cases.map(&:slug)).to eq(['intelligence'])
    end
  end
end
