# frozen_string_literal: true

require 'rails_helper'

describe Portfolio do
  describe '.cases' do
    it 'loads the seven cases in display order' do
      expect(described_class.cases.pluck('slug'))
        .to eq(%w[intelligence dna wardybot leads imagemaker chatgpt rubycoin])
    end

    it 'gives every case the keys the views read' do
      keys = %w[mark title tagline metrics plain mine engineering quality scope_note]

      expect(described_class.cases).to all(include(*keys))
    end
  end

  describe '.cv' do
    it 'loads the CV frame' do
      expect(described_class.cv).to include('name', 'summary', 'experience', 'stacks', 'strengths', 'contact')
    end
  end

  describe '.case!' do
    it 'finds a case by slug' do
      expect(described_class.case!('dna')['mark']).to eq('02')
    end

    it 'raises for an unknown slug' do
      expect { described_class.case!('nope') }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe '.neighbours' do
    it 'returns the previous and next case' do
      previous_case, next_case = described_class.neighbours('wardybot')

      expect([previous_case['slug'], next_case['slug']]).to eq(%w[dna leads])
    end

    it 'wraps at the end of the list' do
      previous_case, next_case = described_class.neighbours('rubycoin')

      expect([previous_case['slug'], next_case['slug']]).to eq(%w[chatgpt intelligence])
    end

    it 'wraps at the start of the list' do
      previous_case, = described_class.neighbours('intelligence')

      expect(previous_case['slug']).to eq('rubycoin')
    end
  end
end
