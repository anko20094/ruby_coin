# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Portfolio::References do
  it 'names every project team.yml credits' do
    expect(described_class.slugs).to include(*Team.credited_slugs)
  end

  it 'names the projects in the owner CV and in the CVs people.yml holds' do
    owner = Team.owner_cv.experience.flat_map { |entry| entry[:case_slugs] }
    others = Team.everyone.reject(&:owner?).filter_map(&:cv).flat_map(&:experience).flat_map { it[:case_slugs] }

    expect(described_class.slugs).to include(*owner, *others)
  end

  it 'counts a hidden person, whose YAML still names the project' do
    hidden = Person.new('id' => 'gone', 'status' => 'hidden', 'cv' => { 'experience' => [{ 'cases' => ['parked'] }] })
    allow(Team).to receive(:everyone).and_return([hidden])

    expect(described_class.named?('parked')).to be(true)
    expect(described_class.named?('nowhere')).to be(false)
  end
end
