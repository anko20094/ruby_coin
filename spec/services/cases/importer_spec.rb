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
end
