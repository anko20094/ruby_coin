# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CV::Importer do
  it 'loads the profile and every block, and says the copy matches' do
    result = described_class.call

    expect(result).to be_clean
    expect(result.blocks.size).to eq(10)
    expect(CVBlock.group(:kind).count).to eq({ 'experience' => 4, 'stack_group' => 2, 'strength' => 4 })
  end

  it 'joins the yaml name and nameUk into one language pair' do
    described_class.call

    expect(CVProfile.current[:name]).to eq({ 'en' => 'Danyil Shkoropad', 'uk' => 'Данило Шкоропад' })
  end

  it 'wraps a bare strength so every block payload has the same shape' do
    described_class.call

    expect(CVBlock.strengths.first.payload.keys).to eq(['text'])
    expect(CVBlock.strengths.first.text).to be_present
  end

  it 'is idempotent — position within a kind is the identity' do
    described_class.call

    expect { described_class.call }.not_to change(CVBlock, :count)
    expect(CVProfile.count).to eq(1)
  end

  it 'puts a drifted field back' do
    described_class.call
    profile = CVProfile.current
    profile.update_columns(updated_on: '1999·01·01')

    described_class.call

    expect(profile.reload.updated_on).not_to eq('1999·01·01')
  end

  it 'carries the case links on the career entries that have them' do
    described_class.call

    expect(CVBlock.experience.first[:case_slugs]).to eq(%w[intelligence leads])
    expect(CVBlock.experience.third[:case_slugs]).to eq([])
  end
end
