# frozen_string_literal: true

require 'rails_helper'

# config/portfolio/people.yml and team.yml have no schema and no validations, and they are the
# only content on the site that names real people. These are the validations.
#
# Before launch, two things here are the owner's rather than the code's: replacing the four
# placeholder records (`grep -r "placeholder: true" config/portfolio` must come back empty) and
# confirming that every named person agreed to be listed.
describe 'the roster content' do
  include_context 'when the cases are imported'
  # The owner's CV — and with it his `updated:` date — is the document in cv.yml, imported on
  # deploy rather than written a second time into people.yml.
  include_context 'when the cv is imported'

  let(:visible_strings) { %i[name role blurb] }
  let(:people) { Team.people }
  let(:crew) { Team.crew }
  let(:optional_for_alumni) { %i[role blurb] }
  let(:contributions) { Case.slugs.flat_map { |slug| Team.for_case(slug) } }

  def in_both_locales(&)
    I18nExtended::AVAILABLE_LOCALES.map { |locale| I18n.with_locale(locale, &) }
  end

  it 'gives every crew member a name, a role and a blurb in both languages' do
    crew.each do |person|
      visible_strings.each do |field|
        values = in_both_locales { person.public_send(field) }

        expect(values).to all(be_present), "#{person.id}.#{field} is missing a language"
        expect(values.uniq.size).to eq(2), "#{person.id}.#{field} is the same string in both languages"
      end
    end
  end

  # An alumnus owes the page a name and nothing else. Demanding a role and a blurb from someone
  # who has left is how a file like this starts holding invented copy about real people — so the
  # rule is inverted here: whatever an alumnus does carry has to be true in both languages.
  it 'asks an alumnus for a name, and for both languages of whatever else they carry' do
    Team.alumni.each do |person|
      names = in_both_locales { person.name }

      expect(names).to all(be_present), "#{person.id} has no name in one of the languages"

      optional_for_alumni.each do |field|
        values = in_both_locales { person.public_send(field) }
        next if values.all?(&:blank?)

        expect(values).to all(be_present), "#{person.id}.#{field} is written in one language only"
      end
    end
  end

  # The point of the status: hiding someone takes their card off the site and leaves their work
  # on it — so a hidden record must still be in the file, and must be off every list.
  it 'keeps a hidden record out of the crew, the alumni and every person page' do
    hidden = Team.everyone.select(&:hidden?)

    expect(people.map(&:id)).not_to include(*hidden.map(&:id)) if hidden.any?
    hidden.each do |person|
      expect { Team.person!(person.id) }.to raise_error(ActiveRecord::RecordNotFound)
      expect(Case.slugs.flat_map { |slug| Team.for_case(slug) }.map(&:person_id)).not_to include(person.id)
    end
  end

  it 'gives every filled CV its summary and stack in both languages' do
    people.select { |person| person.cv.is_a?(Person::CV) }.each do |person|
      expect(in_both_locales { person.cv.summary }).to all(be_present), "#{person.id} cv.summary"
      expect(person.cv.stack_groups).to be_present, "#{person.id} cv.stacks"
      expect(person.cv.experience).to be_present, "#{person.id} cv.experience"
    end
  end

  it 'credits only people who exist' do
    expect(contributions.map(&:person_id).uniq - people.map(&:id)).to eq([])
  end

  # A name with nothing behind it is a pill, not a link. The moment an alumnus is credited on a
  # project the case page links at them, and the page has to be worth opening.
  it 'opens only the records that have something behind the name' do
    Team.people.reject(&:page?).each do |person|
      expect(person.cv).to be_blank, "#{person.id} has a CV and no page"
      expect(person.contributions).to be_empty, "#{person.id} is credited and has no page"
    end
  end

  it 'credits them only on projects that exist' do
    expect(Team.credited_slugs - Case.slugs).to eq([])
  end

  it 'names everyone on every project' do
    expect(Case.slugs.reject { |slug| Team.for_case(slug).any? }).to eq([])
  end

  # Role, period and two lines is the whole format, and it is what keeps six people on one
  # screen without inflation.
  it 'writes two lines per contribution, in both languages' do
    contributions.each do |contribution|
      where = "#{contribution.slug}/#{contribution.person_id}"

      expect(contribution.role).to be_present, "#{where} has no role"
      expect(contribution.period).to be_present, "#{where} has no period"
      expect(in_both_locales { contribution.did }.map(&:size)).to eq([2, 2]), "#{where} is not two lines"
    end
  end

  # A team block with one lonely card reads as an unfinished page; the solo statement reads as
  # a claim. Everything that is not solo has a named team behind it.
  it 'marks a project solo only where one person is credited' do
    Case.slugs.each do |slug|
      team = Team.for_case(slug)
      next unless team.any?(&:solo?)

      expect(team.size).to eq(1), "#{slug} claims solo with #{team.size} people credited"
    end
  end

  it 'never leaves a single-person team without the solo statement' do
    Case.slugs.each do |slug|
      team = Team.for_case(slug)

      expect(team.first).to be_solo, "#{slug} has one contributor and does not say solo" if team.one?
    end
  end

  # The wider team on the commercial work was the client's, and the case page already prints
  # how far down the contributor list this name sits. The two have to agree.
  it 'says whose team the other contributors were on solo commercial work' do
    solo = contributions.select(&:solo?)

    expect(solo).to be_present
    expect(solo.map(&:outside)).to all(be_present)
  end

  it 'labels the machine as a machine, and only that one' do
    machines = people.select(&:machine?)

    expect(machines.map(&:id)).to eq(%w[claude])
    expect(in_both_locales { machines.first.cv.summary }).to all(be_present)
  end

  it 'dates every crew CV, so the staleness chip means something' do
    crew.each do |person|
      expect(person.updated_on).to be_present, "#{person.id} has no usable `updated:` date"
    end
  end

  it 'writes not-work in both languages wherever it is written at all' do
    people.flat_map(&:not_work).each { |item| expect(item[:icon]).to be_present }

    people.select { |person| person.not_work.any? }.each do |person|
      labels = in_both_locales { person.not_work.pluck(:label) }

      expect(labels.flatten).to all(be_present), "#{person.id} has an untranslated not-work label"
    end
  end
end
