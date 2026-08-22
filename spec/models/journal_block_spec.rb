# frozen_string_literal: true

require 'rails_helper'

RSpec.describe JournalBlock do
  describe 'validations' do
    it 'rejects a kind it has no partial for' do
      expect(described_class.new(kind: 'diagram', payload: {})).not_to be_valid
    end

    it 'requires the payload each kind actually needs' do
      expect(described_class.new(kind: 'code', payload: {})).not_to be_valid
      expect(described_class.new(kind: 'code', payload: { 'source' => 'x' })).to be_valid
      expect(described_class.new(kind: 'callout', payload: { 'body' => 'x' })).to be_valid
      expect(described_class.new(kind: 'callout', payload: { 'tone' => 'warn' })).not_to be_valid
    end

    it 'refuses an embed that is not an http url' do
      expect(described_class.new(kind: 'embed', payload: { 'url' => 'javascript:alert(1)' })).not_to be_valid
      expect(described_class.new(kind: 'embed', payload: { 'url' => 'not a url' })).not_to be_valid
      expect(described_class.new(kind: 'embed', payload: { 'url' => 'https://x.com/a' })).to be_valid
    end
  end

  describe 'payload readers' do
    it 'falls back to the note tone for anything unrecognised' do
      expect(described_class.new(payload: { 'tone' => 'shouting' }).tone).to eq('note')
      expect(described_class.new(payload: { 'tone' => 'warn' }).tone).to eq('warn')
    end

    it 'exposes the caption under a name Action Text does not already own' do
      block = described_class.new(payload: { 'caption' => 'The talk' })

      expect(block.embed_caption).to eq('The talk')
      expect(block).not_to respond_to(:caption)
    end
  end

  it 'renders through one partial for every kind' do
    expect(described_class.new(kind: 'code').to_partial_path).to eq('journal_blocks/journal_block')
  end
end
