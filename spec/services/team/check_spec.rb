# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Team::Check do
  include_context 'when the cases are imported'
  include_context 'when the cv is imported'

  let(:tempfiles) { [] }

  def pair(english, ukrainian) = { 'en' => english, 'uk' => ukrainian }

  def person(**attributes)
    names = {
      'id' => 'ghost', 'name' => pair('Ghost', 'Привид'), 'role' => pair('engineer', 'інженер'),
      'blurb' => pair('Writes code.', 'Пише код.'), 'updated' => '2026·09·01'
    }

    Person.new(names.merge(attributes.transform_keys(&:to_s)))
  end

  def problems_for(*people)
    allow(Team).to receive(:everyone).and_return(people)

    described_class.call.problems
  end

  def credit(**row)
    attributes = {
      'person' => 'ghost', 'role' => pair('lead', 'лід'), 'period' => '2024', 'solo' => true,
      'did' => [pair('Built it.', 'Зробив.'), pair('Shipped it.', 'Видав.')],
      'outside' => pair('The client had a team.', 'У клієнта була команда.')
    }

    Contribution.new('dna', attributes.merge(row.transform_keys(&:to_s)))
  end

  def credited(*rows) = allow(Team).to(receive(:contributions).and_return('dna' => rows))

  def yaml_file(name, text)
    file = Tempfile.new([name, '.yml'])
    file.write(text)
    file.flush
    tempfiles << file
    file.path
  end

  after { tempfiles.each(&:close!) }

  it 'finds nothing wrong with the roster that ships, and says which CV is a placeholder' do
    result = described_class.call

    expect(result.problems).to eq([])
    expect(result).to be_ok
    expect(result.notes).to include(a_string_matching(/placeholder CV/))
  end

  describe 'a person id written twice' do
    it 'is named, because Team keeps the last record and the credits move to it' do
      people = yaml_file('people', "people:\n  - id: \"ana\"\n  - id: \"ana\"\n")
      team = yaml_file('team', "contributions:\n  dna:\n    - person: \"ana\"\n")

      result = described_class.new(files: { 'people.yml' => people, 'team.yml' => team }).call

      expect(result.problems).to include(a_string_matching(/people\.yml has 2 records with the id "ana"/))
    end
  end

  describe 'a key written twice' do
    it 'is named with its line, because the second block silently replaces the first' do
      people = yaml_file('people', "people:\n  - id: \"ana\"\n")
      team = yaml_file('team', "contributions:\n  dna:\n    - person: \"ana\"\n  dna:\n    - person: \"bo\"\n")

      result = described_class.new(files: { 'people.yml' => people, 'team.yml' => team }).call

      expect(result.problems).to include(a_string_matching(/team\.yml:\d+ writes "dna" 2 times/))
    end
  end

  describe 'a photo that is not in the repository' do
    it 'is named, because the monogram would raise on every page that draws it' do
      allow(Team).to receive(:everyone).and_return([person(photo: 'nope.jpg')])

      expect(described_class.call.problems).to include(a_string_matching(/ghost names the photo nope\.jpg/))
    end

    it 'is fine when the file is there' do
      allow(Team).to receive(:everyone).and_return([person(photo: 'danyil.jpg')])

      expect(described_class.call.problems).not_to include(a_string_matching(/names the photo/))
    end
  end

  describe 'a status nobody knows' do
    before { allow(Team).to receive(:everyone).and_return([person(status: 'actve'), person(id: 'fine')]) }

    it 'is reported instead of raising, so the problems found are still printed' do
      result = nil

      expect { result = described_class.call }.not_to raise_error
      expect(result.problems).to include(a_string_matching(/ghost: unknown status "actve"/))
    end

    it 'says the other rules were skipped, because they cannot read the roster' do
      expect(described_class.call.notes).to include(a_string_matching(/skipped/))
    end
  end

  describe 'a link to an empty page' do
    before do
      allow(Team).to receive(:everyone).and_return([person])
      allow(Team).to receive(:contributions_of) do |_id, order: nil|
        order ? [] : [instance_double(Contribution, slug: 'left-the-portfolio')]
      end
    end

    it 'is reported when the only credit is on a project that is no longer in the portfolio' do
      expect(described_class.call.problems).to include(a_string_matching(/ghost is linked but .* would be empty/))
    end
  end

  describe 'a string with no English line' do
    it 'is reported as missing in en, not read as the Ukrainian one' do
      uk_only = person(role: { 'uk' => 'інженер' }, blurb: { 'uk' => 'Пише код.' })

      expect(problems_for(uk_only)).to include(
        a_string_matching(/ghost\.role is missing in en\z/), a_string_matching(/ghost\.blurb is missing in en\z/)
      )
    end

    it 'is reported as missing in uk when it is the Ukrainian one that is absent' do
      expect(problems_for(person(name: { 'en' => 'Ghost' })))
        .to include(a_string_matching(/ghost\.name is missing in uk\z/))
    end

    it 'is reported once, as missing, rather than as the same string twice' do
      problems = problems_for(person(role: { 'uk' => 'інженер' })).grep(/ghost\.role/)

      expect(problems.size).to eq(1)
    end

    it 'is fine with one line in each language' do
      expect(problems_for(person).grep(/ghost\.(name|role|blurb)/)).to eq([])
    end

    it 'is reported when the two languages hold the same text' do
      expect(problems_for(person(blurb: 'Writes code.')))
        .to include(a_string_matching(/ghost\.blurb is the same string/))
    end
  end

  describe 'an alumnus' do
    def alumnus(**attributes) = person(status: 'alumni', role: nil, blurb: nil, **attributes)

    it 'owes the page a name in both languages' do
      expect(problems_for(alumnus(name: { 'uk' => 'Привид' }))).to include(a_string_matching(/ghost has no name in en/))
    end

    it 'owes nothing else' do
      expect(problems_for(alumnus)).not_to include(a_string_matching(/ghost/))
    end

    it 'is reported for a role written in one language only' do
      expect(problems_for(alumnus(role: { 'uk' => 'інженер' })))
        .to include(a_string_matching(/ghost\.role is written in uk only/))
    end

    it 'is reported for a blurb written in English only' do
      expect(problems_for(alumnus(blurb: { 'en' => 'Writes code.' })))
        .to include(a_string_matching(/ghost\.blurb is written in en only/))
    end

    it 'is fine with a role in both languages' do
      expect(problems_for(alumnus(role: pair('engineer', 'інженер')))).not_to include(a_string_matching(/ghost\.role/))
    end
  end

  describe 'a CV written in people.yml' do
    def with_cv(**block)
      filled = {
        'summary' => pair('Summary.', 'Підсумок.'), 'stacks' => [{ 'items' => ['Rails'] }],
        'experience' => [{ 'org' => 'RubyCoin' }]
      }

      person(cv: filled.merge(block.transform_keys(&:to_s)))
    end

    it 'is fine with a summary in both languages, a stack and a career' do
      expect(problems_for(with_cv)).not_to include(a_string_matching(/ghost cv\./))
    end

    it 'is reported for a summary with no English' do
      expect(problems_for(with_cv(summary: { 'uk' => 'Підсумок.' })))
        .to include(a_string_matching(/ghost cv\.summary is missing in en/))
    end

    it 'is reported for no stack' do
      expect(problems_for(with_cv(stacks: []))).to include(a_string_matching(/ghost cv\.stacks is empty/))
    end

    it 'is reported for no career' do
      expect(problems_for(with_cv(experience: nil))).to include(a_string_matching(/ghost cv\.experience is empty/))
    end

    it 'is not asked of a record that has no CV yet' do
      expect(problems_for(person(cv: nil))).not_to include(a_string_matching(/ghost cv\./))
    end
  end

  describe 'a contact on a record that is not the owner' do
    def contacting(*rows, **attributes) = person(cv: { 'contact' => rows }, **attributes)

    let(:github) { ['github', 'ghost', 'https://github.com/ghost'] }
    let(:email) { ['email', 'ghost@example.com', 'mailto:ghost@example.com'] }

    it 'is fine when it is a GitHub profile' do
      expect(problems_for(contacting(github))).not_to include(a_string_matching(/ghost publishes/))
    end

    it 'is reported by name when it is an email or a telegram handle' do
      problems = problems_for(contacting(github, email, ['telegram', '@ghost', 'https://t.me/ghost']))

      expect(problems).to include(a_string_matching(/ghost publishes email, telegram; only a GitHub profile is public/))
    end

    it 'is reported when a row named github points anywhere but GitHub' do
      expect(problems_for(contacting(['github', 'ghost', 'mailto:ghost@example.com'])))
        .to include(a_string_matching(/ghost publishes github;/))
    end

    it 'is reported on a hidden record too, because hiding is reversible' do
      expect(problems_for(contacting(email, status: 'hidden'))).to include(a_string_matching(/ghost publishes email/))
    end

    it 'is left alone on the machine, whose rows say where it runs' do
      expect(problems_for(contacting(email, machine: true))).not_to include(a_string_matching(/ghost publishes/))
    end

    it 'is left alone on a placeholder, whose contacts are invented' do
      expect(problems_for(contacting(email, placeholder: true))).not_to include(a_string_matching(/ghost publishes/))
    end

    it 'is left alone on the owner, whose contacts are his own call' do
      expect(problems_for(contacting(email, cv_file: 'cv.yml'))).not_to include(a_string_matching(/ghost publishes/))
    end
  end

  describe 'a crew member with no usable date' do
    it 'is reported, because the staleness chip is read from it' do
      expect(problems_for(person(updated: nil))).to include(a_string_matching(/ghost has no usable `updated:` date/))
      expect(problems_for(person(updated: 'last spring'))).to include(a_string_matching(/ghost has no usable/))
    end

    it 'is not asked of an alumnus' do
      expect(problems_for(person(status: 'alumni', updated: nil))).not_to include(a_string_matching(/usable/))
    end

    it 'is fine with the date the file writes' do
      expect(problems_for(person)).not_to include(a_string_matching(/usable/))
    end
  end

  describe 'what someone does outside work' do
    let(:climbing) { { 'icon' => '🧗', 'label' => pair('climbing', 'скелелазіння') } }

    it 'is fine written in both languages' do
      expect(problems_for(person(not_work: [climbing]))).not_to include(a_string_matching(/not-work/))
    end

    it 'is reported when an item has no icon' do
      expect(problems_for(person(not_work: [climbing.except('icon')])))
        .to include(a_string_matching(/ghost has a not-work item without an icon/))
    end

    it 'is reported when a label has no English' do
      expect(problems_for(person(not_work: [climbing.merge('label' => { 'uk' => 'скелелазіння' })])))
        .to include(a_string_matching(/ghost has a not-work label missing in en/))
    end
  end

  describe 'a credit on a project' do
    before { allow(Team).to receive(:everyone).and_return([person]) }

    def problems_of(*rows)
      credited(*rows)

      described_class.call.problems
    end

    it 'is fine with a role, a period and two lines in both languages' do
      expect(problems_of(credit)).not_to include(a_string_matching(%r{dna/ghost}))
    end

    it 'is reported for a role with no English' do
      expect(problems_of(credit(role: { 'uk' => 'лід' })))
        .to include(a_string_matching(%r{dna/ghost has no role in en}))
    end

    it 'is reported for a period nobody wrote' do
      expect(problems_of(credit(period: nil))).to include(a_string_matching(%r{dna/ghost has no period in uk and en}))
    end

    it 'is reported for a line with no English' do
      lines = [pair('Built it.', 'Зробив.'), { 'uk' => 'Видав.' }]

      expect(problems_of(credit(did: lines))).to include(a_string_matching(%r{dna/ghost has an untranslated line}))
    end

    it 'is reported for a third line, because two is the whole format' do
      lines = [pair('a', 'а'), pair('b', 'б'), pair('c', 'в')]

      expect(problems_of(credit(did: lines))).to include(a_string_matching(%r{dna/ghost is 3 lines, not two}))
    end

    it 'is reported for a person nobody wrote down' do
      expect(problems_of(credit(person: 'nobody')))
        .to include(a_string_matching(%r{dna/nobody names nobody in people\.yml}))
    end

    it 'is reported for a project that is not a case' do
      credited(credit)
      allow(Team).to receive(:contributions).and_return('dna' => [credit], 'ghost-project' => [credit])

      expect(described_class.call.problems).to include(a_string_matching(/ghost-project is credited but is not a case/))
    end

    it 'is reported for a case with nobody on it' do
      expect(problems_of(credit)).to include(a_string_matching(/leads has nobody on it/))
    end
  end

  describe 'a solo project' do
    before { allow(Team).to receive(:everyone).and_return([person, person(id: 'other')]) }

    def problems_of(*rows)
      credited(*rows)

      described_class.call.problems
    end

    it 'is reported when two people are credited on it' do
      expect(problems_of(credit, credit(person: 'other')))
        .to include(a_string_matching(/dna claims solo with 2 credited/))
    end

    it 'is reported when one person is credited and it does not say solo' do
      expect(problems_of(credit(solo: false)))
        .to include(a_string_matching(/dna has one contributor and does not say solo/))
    end

    it 'is reported when it does not say whose team the others were on' do
      expect(problems_of(credit(outside: nil))).to include(a_string_matching(/dna is solo and does not say whose team/))
    end

    it 'is reported when that is said in Ukrainian only' do
      expect(problems_of(credit(outside: { 'uk' => 'У клієнта була команда.' })))
        .to include(a_string_matching(/dna is solo and does not say whose team/))
    end

    it 'is fine when it does' do
      expect(problems_of(credit)).not_to include(a_string_matching(/dna (is solo|claims|has one)/))
    end
  end
end
