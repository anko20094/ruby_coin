# frozen_string_literal: true

require 'rails_helper'

describe TeamController do
  render_views

  include_context 'when the cases are imported'
  include_context 'when the cv is imported'

  describe 'GET #index' do
    let(:action) { :index }
    let(:params) { { locale: 'en' } }

    it_behaves_like 'has http success'

    it 'renders one card per person, in file order' do
      get(action, params:)

      expect(response.body.scan('class="tm-card hover-row"').size).to eq(Team.people.size)
      expect(response.body.index('Danyil')).to be < response.body.index('Claude')
    end

    it 'links each card at that person, and counts their projects' do
      get(action, params:)

      expect(response.body).to include(person_path('natalia', locale: 'en'))
      expect(response.body).to include('4 projects')
    end

    # Four records carry invented dates and employers. They say so on the card and again on the
    # page; `grep -r "placeholder: true" config/portfolio` is the check before launch.
    it 'chips every placeholder record' do
      get(action, params:)

      expect(response.body.scan('PLACEHOLDER').size).to eq(Team.people.count(&:placeholder?))
    end

    it 'renders the Ukrainian copy under the uk locale' do
      get(action, params: { locale: 'uk' })

      expect(response.body).to include('Хто тут є', 'Наталя')
    end
  end

  describe 'GET #show' do
    let(:action) { :show }
    let(:params) { { locale: 'en', id: 'natalia' } }

    it_behaves_like 'has http success'

    it 'renders the CV written in people.yml' do
      get(action, params:)

      expect(response.body).to include('pf-career', 'pgvector')
    end

    it "renders the owner's CV from the database, so it is the one /cv shows" do
      get(action, params: { locale: 'en', id: 'danyil' })

      expect(response.body).to include(I18n.with_locale(:en) { CVProfile.current.summary })
    end

    it 'lists every project the person worked on, each anchored for a deep link' do
      get(action, params:)

      expect(response.body.scan('class="worked-row hover-row').size).to eq(4)
      expect(response.body).to include('id="c-dna"')
    end

    it 'prints the placeholder banner on a record whose dates are invented' do
      get(action, params:)

      expect(response.body).to include('pf-placeholder')
    end

    it 'leaves the banner off a real record' do
      get(action, params: { locale: 'en', id: 'claude' })

      expect(response.body).not_to include('pf-placeholder')
    end

    it 'raises for a person nobody is' do
      expect { get(action, params: { locale: 'en', id: 'nobody' }) }.to raise_error(ActiveRecord::RecordNotFound)
    end

    # The whole point of the design: the visitor arrived asking what this person did on that
    # project, and the answer is above the CV rather than under it.
    describe 'arriving from a project' do
      it 'pins that contribution at the top and highlights its row' do
        get(action, params: params.merge(from: 'dna'))

        expect(response.body).to include('tm-context')
        expect(response.body).to include('worked-row hover-row is-here')
        expect(response.body.index('tm-context')).to be < response.body.index('pf-career')
      end

      it 'links back to the case it came from' do
        get(action, params: params.merge(from: 'dna'))

        expect(response.body).to include(work_case_path(slug: 'dna', locale: 'en'))
      end

      # A stale link degrades to the plain page rather than to an error.
      it 'ignores a project this person did not work on' do
        get(action, params: params.merge(from: 'leads'))

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
        get(action, params: { locale: 'en', id: 'newcomer' })

        expect(response.body).to include('pf-pending')
        expect(response.body).to include(I18n.t('profile.pending.title', locale: :en))
        expect(response.body).not_to include('pf-career')
      end

      it 'keeps the sidebar shape, with em-dashes where the panel would be' do
        get(action, params: { locale: 'en', id: 'newcomer' })

        expect(response.body).to include('pf-contact--empty')
      end
    end
  end
end
