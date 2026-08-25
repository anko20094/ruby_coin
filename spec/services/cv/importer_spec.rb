# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CV::Importer do
  it 'loads the whole CV into one row, and says the copy matches' do
    result = described_class.call

    expect(result).to be_clean
    profile = CVProfile.current
    expect(profile.experience.size).to eq(4)
    expect(profile.stack_groups.size).to eq(2)
    expect(profile.strengths.size).to eq(4)
  end

  it 'joins the yaml name and nameUk into one language pair' do
    described_class.call

    expect(CVProfile.current[:name]).to eq({ 'en' => 'Danyil Shkoropad', 'uk' => 'Данило Шкоропад' })
  end

  # A strength is a bare {en, uk} in the YAML, and the row is that value — it used to be
  # wrapped under a 'text' key so every cv_blocks payload had the same shape, and there is no
  # longer a payload to keep uniform.
  it 'keeps a strength as the language pair it is' do
    described_class.call

    expect(CVProfile.current[:strengths].first.keys).to match_array(%w[en uk])
    expect(CVProfile.current.strengths.first).to be_present
  end

  it 'is idempotent — the CV is one row, so re-importing rewrites it' do
    described_class.call

    expect { described_class.call }.not_to change(CVProfile, :count)
    expect(CVProfile.current.experience.size).to eq(4)
  end

  it 'puts a drifted field back' do
    described_class.call
    profile = CVProfile.current
    profile.update_columns(figures_as_of: '1999·01·01')

    described_class.call

    expect(profile.reload.figures_as_of).not_to eq('1999·01·01')
  end

  it 'puts a drifted list back too' do
    described_class.call
    CVProfile.current.update_columns(strengths: [])

    described_class.call

    expect(CVProfile.current.strengths.size).to eq(4)
  end

  it 'carries the case links on the career entries that have them' do
    described_class.call

    expect(CVProfile.current.experience.first[:case_slugs]).to eq(%w[intelligence leads])
    expect(CVProfile.current.experience.third[:case_slugs]).to eq([])
  end
end
