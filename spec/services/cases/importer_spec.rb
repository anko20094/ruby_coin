# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Cases::Importer do
  it 'loads every case from the yaml in display order' do
    result = described_class.call

    expect(result.imported).to eq(%w[intelligence dna wardybot leads imagemaker chatgpt rubycoin])
    expect(Case.ordered.pluck(:slug)).to eq(result.imported)
    expect(Case.ordered.pluck(:mark)).to eq(%w[01 02 03 04 05 06 07])
  end

  # This is the point of the class: a figure that changed shape on the way into JSONB has to
  # be reported, not shrugged off.
  it 'reports that the stored copy matches the source' do
    expect(described_class.call).to be_clean
  end

  it 'is idempotent — running it twice leaves seven cases, not fourteen' do
    described_class.call

    expect { described_class.call }.not_to change(Case, :count)
  end

  it 'overwrites a field that has drifted from the source' do
    described_class.call
    dna = Case.find_by!(slug: 'dna')
    dna.update_columns(year: '1999')

    described_class.call

    expect(dna.reload.year).not_to eq('1999')
  end

  it 'marks only the case that says it is this site' do
    described_class.call

    expect(Case.where(is_this_site: true).pluck(:slug)).to eq(['rubycoin'])
    expect(Case.where(own: true).count).to eq(5)
  end

  describe 'when the copy cannot be trusted' do
    let(:file) { Tempfile.new(['cases', '.yml']) }

    after { file.close! }

    def source_with(count: 3)
      data = YAML.load_file(described_class::SOURCE)
      data['cases'] = data['cases'].first(count)
      yield data['cases']
      file.write(data.to_yaml)
      file.flush
      file.path
    end

    it 'reports an unquoted yaml number read back from a string column, and commits none of it' do
      path = source_with { |cases| cases.second['mark'] = 2 }

      result = described_class.new(path).call

      expect(result).not_to be_clean
      expect(result.mismatches).to include(a_string_matching(/dna\.mark: expected 2, stored "2"/))
      expect(result.imported).to be_empty
      expect(Case.count).to eq(0)
    end

    it 'puts back the rows it had overwritten when the read-back disagrees' do
      described_class.call
      before = Case.order(:position).pluck(:slug, :updated_at)
      path = source_with { |cases| cases.second['mark'] = 2 }

      described_class.new(path).call

      expect(Case.order(:position).pluck(:slug, :updated_at).first(3)).to eq(before.first(3))
      expect(Case.find_by!(slug: 'dna').mark).to eq('02')
    end

    it 'writes none of the cases when a later one is invalid' do
      path = source_with { |cases| cases.third['title']['uk'] = '' }

      expect { described_class.new(path).call }.to raise_error(ActiveRecord::RecordInvalid)
      expect(Case.count).to eq(0)
    end
  end

  it 'names the case left behind when one is renamed, because the file creates its own beside it' do
    described_class.call
    Case.find_by!(slug: 'dna').update_columns(slug: 'dna-renamed')

    result = described_class.call

    expect(result.strays).to eq(['dna-renamed'])
    expect(Case.count).to eq(8)
  end

  it 'has no strays when the table holds only what the file names' do
    expect(described_class.call.strays).to eq([])
  end
end
