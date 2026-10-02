# frozen_string_literal: true

require 'rails_helper'

# config/portfolio/people.yml and team.yml have no schema and no validations, and they are the
# only content on the site that names real people. The rules are Team::Check's, so `rake team:check`
# and this spec cannot disagree; what stays here is what only a rendered page can show.
#
# Before launch, two things here are the owner's rather than the code's: keeping the file free of
# placeholder records (`grep -n '^ *placeholder: true' config/portfolio/people.yml` must come back
# empty) and confirming that every named person agreed to be listed.
describe 'the roster content' do
  include_context 'when the cases are imported'
  # The owner's CV — and with it his `updated:` date — is the document in cv.yml, imported on
  # deploy rather than written a second time into people.yml.

  it 'breaks none of the rules the roster pages rely on' do
    expect(Team::Check.call.problems).to eq([])
  end

  # The gate is only worth having if it can go red. One broken record per family of rules, built
  # in memory; spec/services/team/check_spec.rb has the rest.
  describe 'a roster with a rule broken' do
    def broken(**attributes)
      names = {
        'id' => 'ghost', 'name' => { 'en' => 'Ghost', 'uk' => 'Привид' }, 'updated' => '2026·09·01',
        'role' => { 'en' => 'engineer', 'uk' => 'інженер' }, 'blurb' => { 'en' => 'Writes.', 'uk' => 'Пише.' }
      }

      Person.new(names.merge(attributes.transform_keys(&:to_s)))
    end

    let(:filled_cv) do
      {
        'summary' => { 'en' => 'Hi.', 'uk' => 'Привіт.' }, 'stacks' => [{ 'items' => ['Rails'] }],
        'experience' => [{ 'org' => 'RubyCoin' }]
      }
    end
    let(:findings) do
      {
        'a crew string with no English' => [{ role: { 'uk' => 'інженер' } }, /ghost\.role is missing in en/],
        'an alumnus role in one language' =>
          [{ status: 'alumni', role: { 'en' => 'engineer' } }, /ghost\.role is written/],
        'a filled CV with no stack' => [{ cv: filled_cv.merge('stacks' => []) }, /ghost cv\.stacks is empty/],
        'a contact that is not GitHub' =>
          [{ cv: { 'contact' => [['email', 'a@b.c', 'mailto:a@b.c']] } }, /ghost publishes email/],
        'a crew record with no date' => [{ updated: nil }, /ghost has no usable `updated:` date/],
        'a not-work item with no English' =>
          [{ not_work: [{ 'icon' => '🧗', 'label' => { 'uk' => 'скелелазіння' } }] }, /ghost has a not-work label/]
      }
    end

    it 'is reported, whichever family of rules it breaks' do
      findings.each do |rule, (attributes, finding)|
        allow(Team).to receive(:everyone).and_return([broken(**attributes)])

        result = Team::Check.call

        expect(result).not_to be_ok, "#{rule} went unreported"
        expect(result.problems).to include(a_string_matching(finding)), rule
      end
    end

    it 'is reported for a credit that names nobody' do
      allow(Team).to receive(:contributions).and_return('dna' => [Contribution.new('dna', { 'person' => 'nobody' })])

      expect(Team::Check.call.problems).to include(a_string_matching(%r{dna/nobody names nobody in people\.yml}))
    end
  end

  # Hiding someone takes their card off the site and leaves their work on it. The shipped file has
  # no hidden record, so the roster is stubbed to hold one.
  describe 'a hidden record' do
    include_context 'when errors render as pages'

    let(:hidden) { Person.new('id' => 'natalia', 'status' => 'hidden', 'name' => { 'en' => 'Absent' }) }
    let(:link) { '/team/natalia' }
    let(:pages) do
      [
        root_path(locale: 'en'), team_path(locale: 'en'), studio_path(locale: 'en'),
        work_case_path(slug: 'dna', locale: 'en'), sitemap_path,
        search_path(locale: 'en', query: 'natalia', format: :json)
      ]
    end

    def hide_natalia
      allow(Team).to(receive(:roster).and_wrap_original { |original| original.call.merge('natalia' => hidden) })
    end

    it 'is drawn on every page that lists them, and on none once they are hidden' do
      pages.each do |path|
        get path
        expect(response).to have_http_status(:ok), path
        expect(response.body).to include(link), "#{path} does not link natalia while she is on the crew"
      end

      hide_natalia

      pages.each do |path|
        get path
        expect(response).to have_http_status(:ok), path
        expect(response.body).not_to include(link), "#{path} still links natalia while she is hidden"
      end
    end

    it 'has a page that answers 404 rather than a CV' do
      hide_natalia

      get person_path('natalia', locale: 'en')

      expect(response).to have_http_status(:not_found)
      expect(response.body).to include('er-page')
    end
  end

  describe 'a placeholder on the crew' do
    let(:stand_in) do
      Person.new('id' => 'stand-in', 'short' => 'SI', 'placeholder' => true, 'name' => { 'en' => 'Stand In' },
                 'role' => { 'en' => 'engineer' }, 'blurb' => { 'en' => 'Invented.' })
    end

    before { allow(Team).to receive(:everyone).and_return(Team.everyone + [stand_in]) }

    it 'carries the chip once on the roster and once on the studio page' do
      expect(Team.crew.count(&:placeholder?)).to eq(1)

      [team_path(locale: 'en'), studio_path(locale: 'en')].each do |path|
        get path

        expect(Capybara.string(response.body))
          .to have_css('.tm-card__chip.is-placeholder', text: 'PLACEHOLDER', count: 1), path
      end
    end
  end

  # A name with nothing behind it is a pill, not a link. The moment an alumnus is credited on a
  # project the case page links at them, and the page has to be worth opening.
  describe 'the page behind a name' do
    include_context 'when errors render as pages'

    # No alumnus in the shipped file is credited on a project today, so one who is stands in:
    # vladyslav, off the crew and keeping his credits.
    let(:credited_alumnus) do
      Person.new('id' => 'vladyslav', 'status' => 'alumni', 'name' => { 'en' => 'Vladyslav', 'uk' => 'Владислав' })
    end

    before do
      allow(Team).to(receive(:roster).and_wrap_original do |original|
        original.call.merge('vladyslav' => credited_alumnus)
      end)
    end

    it 'opens for the crew, and for an alumnus only when something is behind the name' do
      expect(Team.alumni.reject(&:page?)).to be_present, 'every alumnus has a page, so this rule proves nothing'
      expect(Team.alumni.select(&:page?)).to be_present

      (Team.crew + Team.alumni).each do |person|
        get person_path(person, locale: 'en')

        expect(response).to have_http_status(person.active? || person.page? ? :ok : :not_found), person.id
      end
    end
  end

  it 'labels the machine as a machine, and only that one' do
    expect(Team.people.select(&:machine?).map(&:id)).to eq(%w[claude])
  end
end
