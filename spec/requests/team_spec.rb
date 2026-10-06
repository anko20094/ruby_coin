# frozen_string_literal: true

require 'rails_helper'

describe 'the team pages', type: :request do
  include_context 'when the cases are imported'

  describe 'GET /team' do
    it 'renders one card per person, in file order' do
      get team_path(locale: 'en')

      expect(response).to have_http_status(:ok)
      expect(response.body.scan('class="tm-card hover-row"').size).to eq(Team.crew.size)
      expect(response.body.index('Danyil')).to be < response.body.index('Claude')
    end

    it 'links each card at that person, and counts their projects' do
      get team_path(locale: 'en')

      expect(response.body).to include(person_path('natalia', locale: 'en'))
      expect(response.body).to include('4 projects')
    end

    describe 'a placeholder on the crew' do
      let(:stand_in) do
        Person.new('id' => 'stand-in', 'short' => 'SI', 'placeholder' => true, 'name' => { 'en' => 'Stand In' },
                   'role' => { 'en' => 'engineer' }, 'blurb' => { 'en' => 'Invented.' })
      end

      before { allow(Team).to receive(:everyone).and_return(Team.everyone + [stand_in]) }

      it 'chips its card' do
        expect(Team.crew.count(&:placeholder?)).to eq(1)

        get team_path(locale: 'en')

        expect(Capybara.string(response.body))
          .to have_css('.tm-card__chip.is-placeholder', text: 'PLACEHOLDER', count: 1)
      end
    end

    it 'renders the Ukrainian copy under the uk locale' do
      get team_path(locale: 'uk')

      expect(response.body).to include('Хто тут є', 'Наталія')
    end
  end

  describe 'GET /team/:id' do
    it 'renders the CV written in people.yml' do
      get person_path('natalia', locale: 'en')

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('pf-career', 'Capybara')
    end

    it "renders the owner's CV from the database, so it is the one /cv shows" do
      get person_path('danyil', locale: 'en')

      expect(response.body).to include(I18n.with_locale(:en) { Team.owner_cv.summary })
    end

    it 'lists every project the person worked on, each anchored for a deep link' do
      get person_path('natalia', locale: 'en')

      expect(response.body.scan('class="worked-row hover-row').size).to eq(Team.contributions_of('natalia').size)
      expect(response.body).to include('id="c-dna"')
    end

    # No record ships as a placeholder, so the banner is checked on one built in memory.
    it 'prints the placeholder banner on a record whose dates are invented' do
      stand_in = Person.new(
        'id' => 'stand-in', 'short' => 'SI', 'placeholder' => true, 'updated' => '2026·09·01',
        'name' => { 'en' => 'Stand In' }, 'role' => { 'en' => 'engineer' }, 'blurb' => { 'en' => 'Invented.' },
        'cv' => {
          'role' => { 'en' => 'Engineer' }, 'summary' => { 'en' => 'Invented.' },
          'experience' => [{ 'period' => '2024', 'org' => 'RubyCoin', 'body' => { 'en' => 'Invented.' } }],
          'stacks' => [{ 'label' => { 'en' => 'core' }, 'items' => ['Ruby'] }]
        }
      )
      allow(Team).to receive(:person).and_call_original
      allow(Team).to receive(:person).with('stand-in').and_return(stand_in)

      get person_path('stand-in', locale: 'en')

      expect(response.body).to include('pf-placeholder')
    end

    it 'ships no placeholder record' do
      expect(Team.everyone.select(&:placeholder?)).to be_empty
    end

    it 'leaves the banner off a real record' do
      get person_path('claude', locale: 'en')

      expect(response.body).not_to include('pf-placeholder')
    end

    # The page behind a bare name would have to be invented, which is why /studio draws no link.
    it 'is not found for an alumnus who is only a name' do
      expect(Team.person('andrii-mazurok')).not_to be_page

      get person_path('andrii-mazurok', locale: 'en')

      expect(response).to have_http_status(:not_found)
    end

    it 'opens an alumnus who is still credited on a project' do
      expect(Team.person('oleksandr')).to be_alumni.and be_page

      get person_path('oleksandr', locale: 'en')

      expect(response).to have_http_status(:success)
    end

    # His CV was a layout stand-in; what is left is the credits, which are real.
    it 'shows that alumnus as a draft, with nothing invented on the page' do
      get person_path('oleksandr', locale: 'en')

      expect(Team.person('oleksandr')).not_to be_cv
      expect(response.body).not_to include('placeholder@', 'pf-placeholder')
      expect(response.body).to include(I18n.t('profile.pending.title', locale: :en))
    end

    # The visitor asked what this person did on that project; the answer sits above the CV.
    describe 'arriving from a project' do
      it 'pins that contribution at the top and highlights its row' do
        get person_path('natalia', locale: 'en', from: 'dna')

        expect(response.body).to include('tm-context')
        expect(response.body).to include('worked-row hover-row is-here')
        expect(response.body.index('tm-context')).to be < response.body.index('pf-career')
      end

      it 'links back to the case it came from' do
        get person_path('natalia', locale: 'en', from: 'dna')

        expect(response.body).to include(work_case_path(slug: 'dna', locale: 'en'))
      end

      # A stale link degrades to the plain page rather than to an error.
      it 'ignores a project this person did not work on' do
        get person_path('natalia', locale: 'en', from: 'leads')

        expect(response).to have_http_status(:success)
        expect(response.body).not_to include('tm-context')
      end
    end

    describe 'a CV nobody has written yet' do
      let(:newcomer) do
        Person.new('id' => 'newcomer', 'short' => 'NX',
                   'name' => { 'en' => 'Newcomer', 'uk' => 'Новенький' },
                   'role' => { 'en' => 'engineer', 'uk' => 'інженер' },
                   'blurb' => { 'en' => 'Started last week.', 'uk' => 'Почав минулого тижня.' },
                   'cv' => nil)
      end

      before { allow(Team).to receive(:person!).with('newcomer').and_return(newcomer) }

      it 'says so, and does not invent a career to fill the layout' do
        get person_path('newcomer', locale: 'en')

        expect(response.body).to include('pf-pending')
        expect(response.body).to include(I18n.t('profile.pending.title', locale: :en))
        expect(response.body).not_to include('pf-career')
      end

      it 'keeps the sidebar shape, with em-dashes where the panel would be' do
        get person_path('newcomer', locale: 'en')

        expect(response.body).to include('pf-contact--empty')
      end
    end
  end
end
