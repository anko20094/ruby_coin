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

    expect(CVProfile.current[:name]).to eq({ 'en' => 'Danyil Shkoropad', 'uk' => 'Даниїл Шкоропад' })
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

  describe 'when the copy cannot be trusted' do
    let(:file) { Tempfile.new(['cv', '.yml']) }

    after { file.close! }

    def source_with
      data = YAML.load_file(described_class::SOURCE)
      yield data['cv']
      file.write(data.to_yaml)
      file.flush
      file.path
    end

    it 'reports an unquoted yaml number read back from a string column, and writes no row' do
      path = source_with { |cv| cv['updated'] = 2026 }

      result = described_class.new(path).call

      expect(result).not_to be_clean
      expect(result.mismatches).to include(a_string_matching(/profile\.figures_as_of: expected 2026, stored "2026"/))
      expect(CVProfile.count).to eq(0)
    end

    it 'leaves the row it already has as it was' do
      described_class.call
      path = source_with do |cv|
        cv['updated'] = 2026
        cv['strengths'] = []
      end

      described_class.new(path).call

      expect(CVProfile.current.strengths.size).to eq(4)
      expect(CVProfile.current.figures_as_of).not_to eq('2026')
    end
  end
end
