# frozen_string_literal: true

require 'rails_helper'

# The number the handoff says should decide the order of /work, and which nothing was counting.
describe Statistics::CaseViewsQuery, type: :query do
  subject(:result) { described_class.new.count }

  include_context 'when the cases are imported'

  it 'lists every case, including the ones nobody has opened' do
    expect(result.size).to eq(Case.count)
    expect(result.map(&:last)).to all(eq(0))
  end

  it 'counts the views a case has' do
    dna = Case.find_by!(slug: 'dna')
    2.times { create(:ahoy_event, name: 'Viewed Case', properties: { case_id: dna.id }) }

    expect(result.to_h[dna]).to eq(2)
  end

  it 'does not count post views' do
    dna = Case.find_by!(slug: 'dna')
    create(:ahoy_event, name: 'Viewed Post', properties: { post_id: dna.id })

    expect(result.to_h[dna]).to eq(0)
  end
end
