# frozen_string_literal: true

require 'rails_helper'

# The roster is config/portfolio/people.yml and config/portfolio/team.yml, so these examples run
# against the real content the site ships — the same reasoning as the importer specs. A YAML
# file has no validations, and this is where it gets them.
RSpec.describe Team do
  include_context 'when the cases are imported'

  describe '.people' do
    it 'reads the roster in file order, which is display order' do
      expect(described_class.crew.map(&:id)).to eq(%w[danyil mykhailo oleksii natalia vladyslav claude])
    end

    it 'separates the crew from the people who have left, and loses nobody between them' do
      expect(described_class.people).to match_array(described_class.crew + described_class.alumni)
      expect(described_class.crew & described_class.alumni).to be_empty
      expect(described_class.alumni.map(&:id)).to include('oleksandr')
    end
  end

  # Hiding someone is the one operation with no example in the shipped content — the file has no
  # hidden record and should not need one to keep the mechanism working. So the roster is stubbed
  # here rather than edited, and the point being proved is that a hidden person leaves every list
  # while their rows in team.yml stay exactly where they were.
  describe 'a hidden record' do
    let(:absent) { Person.new('id' => 'absent', 'status' => 'hidden', 'name' => { 'en' => 'Absent' }) }

    before do
      described_class.reload!
      allow(described_class).to receive(:everyone).and_return(described_class.crew + [absent])
      allow(described_class).to receive(:person).and_wrap_original do |original, id|
        id.to_s == 'absent' ? absent : original.call(id)
      end
    end

    after { described_class.reload! }

    it 'is in the file and on none of the lists' do
      expect(described_class.everyone).to include(absent)
      expect(described_class.people).not_to include(absent)
      expect(described_class.crew).not_to include(absent)
      expect(described_class.alumni).not_to include(absent)
    end

    it 'has no page, so the link nobody should follow cannot be built' do
      expect(absent).not_to be_page
      expect { described_class.person!('absent') }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'takes their credits off the case pages without taking them out of team.yml' do
      allow(described_class).to receive(:person).with('natalia').and_return(absent)

      expect(described_class.for_case('dna').map(&:person_id)).not_to include('natalia')
      expect(described_class.contributions_of('natalia')).to be_present
    end
  end

  describe '.person!' do
    it 'finds a person by id' do
      expect(described_class.person!('natalia').short).to eq('NM')
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
      expect(described_class.contributions_of('mykhailo').map(&:slug))
        .to match_array(%w[dna wardybot imagemaker chatgpt rubycoin])
    end

    it "orders them by the projects' own display order, not by this file's" do
      order = Case.slugs

      expect(described_class.contributions_of('mykhailo', order: order).map(&:slug))
        .to eq(%w[dna wardybot imagemaker chatgpt rubycoin])
    end

    # Otherwise a project taken off /work leaves a row pointing at a 404 behind it.
    it 'drops a contribution whose project is no longer in the portfolio' do
      expect(described_class.contributions_of('mykhailo', order: %w[dna rubycoin]).map(&:slug))
        .to eq(%w[dna rubycoin])
    end
  end

  describe '.version' do
    # A page cached on the roster has to expire when the roster does, and the files are the
    # only thing that can say so — there is no updated_at on a YAML file worth trusting.
    it 'is a digest' do
      expect(described_class.version).to match(/\A\h{64}\z/)
    end

    context 'when a photograph is replaced under the same filename' do
      let(:photos) { Pathname(Dir.mktmpdir) }
      let(:photo) { photos.join('natalia.jpg') }

      before do
        photo.binwrite('the first face')
        stub_const('Team::PHOTOS', photos)
        described_class.reload!
      end

      after do
        FileUtils.remove_entry(photos)
        described_class.reload!
      end

      it 'moves, and settles when the old one is put back' do
        first = described_class.version

        photo.binwrite('the second face')
        described_class.reload!
        expect(described_class.version).not_to eq(first)

        photo.binwrite('the first face')
        described_class.reload!
        expect(described_class.version).to eq(first)
      end
    end
  end
end
