# frozen_string_literal: true

require 'rails_helper'

# The roster is config/portfolio/people.yml and config/portfolio/team.yml, so these examples run
# against the real content the site ships — the same reasoning as the importer specs. A YAML
# file has no validations, and this is where it gets them.
RSpec.describe Team do
  include_context 'when the cases are imported'

  describe '.people' do
    it 'reads the roster in file order, which is display order' do
      expect(described_class.people.map(&:id)).to eq(%w[danyil mykhailo oleksii oleksandr natalia claude])
    end
  end

  describe '.person!' do
    it 'finds a person by id' do
      expect(described_class.person!('natalia').short).to eq('NT')
    end

    it 'raises for an id nobody has, so a bad link is a 404 rather than a blank page' do
      expect { described_class.person!('nobody') }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe '.owner' do
    it 'is the one person whose CV is the document in cv.yml' do
      expect(described_class.owner.id).to eq('danyil')
      expect(described_class.people.count(&:owner?)).to eq(1)
    end
  end

  describe '.for_case' do
    it 'lists who worked on a project, in file order' do
      expect(described_class.for_case('dna').map(&:person_id))
        .to eq(%w[danyil mykhailo natalia oleksii oleksandr claude])
    end

    it 'answers with nothing for a project nobody is credited on' do
      expect(described_class.for_case('not-a-project')).to eq([])
    end
  end

  describe '.contributions_of' do
    it 'returns every project one person touched' do
      expect(described_class.contributions_of('natalia').map(&:slug))
        .to match_array(%w[dna wardybot imagemaker rubycoin])
    end

    it "orders them by the projects' own display order, not by this file's" do
      order = Case.slugs

      expect(described_class.contributions_of('natalia', order: order).map(&:slug))
        .to eq(%w[dna wardybot imagemaker rubycoin])
    end

    # Otherwise a project taken off /work leaves a row pointing at a 404 behind it.
    it 'drops a contribution whose project is no longer in the portfolio' do
      expect(described_class.contributions_of('natalia', order: %w[dna rubycoin]).map(&:slug))
        .to eq(%w[dna rubycoin])
    end
  end

  describe '.version' do
    # A page cached on the roster has to expire when the roster does, and the files are the
    # only thing that can say so — there is no updated_at on a YAML file worth trusting.
    it 'is a digest of the two files' do
      expect(described_class.version).to match(/\A\h{64}\z/)
    end
  end
end
