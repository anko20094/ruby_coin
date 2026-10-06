# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Person do
  subject(:person) { described_class.new(attributes) }

  let(:attributes) do
    {
      'id' => 'newcomer', 'short' => 'NX',
      'name' => { 'en' => 'Newcomer', 'uk' => 'Новенький' },
      'role' => { 'en' => 'engineer', 'uk' => 'інженер' },
      'blurb' => { 'en' => 'Started last week.', 'uk' => 'Почав минулого тижня.' },
      'updated' => nil, 'cv' => nil
    }
  end

  it 'reads its strings in the current locale' do
    I18n.with_locale(:uk) { expect(person.name).to eq('Новенький') }
    I18n.with_locale(:en) { expect(person.name).to eq('Newcomer') }
  end

  # The state a new hire lands in on day one. Nothing is invented in their place.
  describe 'without a CV' do
    it 'has none, and says so through #draft?' do
      expect(person.cv).to be_nil
      expect(person).not_to be_cv
      expect(person).to be_draft
    end

    it 'publishes no links for a search engine to follow' do
      expect(person.public_links).to eq([])
    end
  end

  describe 'with a CV written in people.yml' do
    subject(:person) { Team.person!('claude') }

    it 'reads it as the same document the CV page renders' do
      expect(person.cv).to be_a(Person::CV)
      expect(person.cv.experience.first[:case_slugs]).to include('dna')
      expect(I18n.with_locale(:uk) { person.cv.summary }).to include('pull request')
    end

    it 'is not a draft while its date is fresh' do
      expect(person).not_to be_draft
    end
  end

  describe 'with the CV that lives in cv.yml' do
    subject(:person) { Team.owner }

    it 'resolves to the one document /cv renders, so the two pages cannot drift' do
      expect(person.cv).to equal(Team.owner_cv)
      expect(I18n.with_locale(:en) { person.cv.name }).to eq('Danyil Shkoropad')
      expect(I18n.with_locale(:uk) { person.cv.name }).to eq('Даниїл Шкоропад')
    end

    it 'takes its date from the CV rather than from a second copy in people.yml' do
      expect(person.updated).to eq(YAML.load_file(Team::PATH.join('cv.yml')).dig('cv', 'updated'))
    end

    it 'reads no CV from the database' do
      statements = []
      collect = ->(*, payload) { statements << payload[:sql] unless payload[:name] == 'SCHEMA' }

      ActiveSupport::Notifications.subscribed(collect, 'sql.active_record') do
        [person.cv, person.updated_on, person.draft?, person.public_links]
      end

      expect(statements).to be_empty
    end

    it 'publishes the contact links the CV already shows' do
      expect(person.public_links).to include('https://github.com/anko20094')
      expect(person.public_links).to all(satisfy { |link| !link.start_with?('mailto:') })
    end
  end

  describe '#draft?' do
    it 'is true for a CV nobody has dated' do
      expect(described_class.new(attributes.merge('cv' => { 'summary' => 'x' }))).to be_draft
    end

    # A stale CV is worse than an absent one — it makes every other figure look unmaintained.
    it 'is true for a CV older than a year' do
      stale = attributes.merge('cv' => { 'summary' => 'x' }, 'updated' => 2.years.ago.strftime('%Y·%m·%d'))

      expect(described_class.new(stale)).to be_draft
    end

    it 'is false for a CV dated this year' do
      fresh = attributes.merge('cv' => { 'summary' => 'x' }, 'updated' => 1.month.ago.strftime('%Y·%m·%d'))

      expect(described_class.new(fresh)).not_to be_draft
    end
  end

  describe '#not_work' do
    it 'is optional, and empty rather than missing when a record has none' do
      expect(person.not_work).to eq([])
    end

    it 'carries both languages, and leaves the detail out where there is none' do
      items = I18n.with_locale(:uk) { Team.person!('oleksii').not_work }

      expect(items.pluck(:label)).to all(be_present)
      expect(items.pluck(:detail)).to include(nil)
    end
  end
end
