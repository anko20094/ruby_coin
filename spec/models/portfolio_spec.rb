# frozen_string_literal: true

require 'rails_helper'

describe Portfolio do
  describe '.cv' do
    it 'loads the CV frame' do
      expect(described_class.cv).to include('name', 'summary', 'experience', 'stacks', 'strengths', 'contact')
    end
  end

  describe '.portrait' do
    it 'finds the portrait that is in place' do
      expect(described_class.portrait).to eq('work-portrait.jpg')
    end
  end
end
