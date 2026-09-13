# frozen_string_literal: true

require 'rails_helper'

describe WorkController do
  render_views

  include_context 'when the cases are imported'
  include_context 'when the cv is imported'

  describe 'GET #index' do
    let(:action) { :index }
    let(:params) { { locale: 'uk' } }

    it_behaves_like 'has http success'

    it 'renders one card per project, all the same size' do
      get(action, params:)

      expect(response.body.scan('class="wk-project hover-row"').size).to eq(7)
    end

    # Hand-ordered and numbered reads as a rank. The mark stays on the case page and on /cv,
    # where it reads as an index.
    it 'prints no case mark on the cards' do
      get(action, params:)

      expect(response.body).not_to include('wk-project__mark')
    end

    it 'shows who built each project, or says solo' do
      get(action, params: { locale: 'en' })

      expect(response.body).to include('rc-monogram')
      # myHomeIQ Intelligence and Leads: the wider team there was the client's.
      expect(response.body.scan('>solo<').size).to eq(2)
      # Not "6 people": one of the six credited on DNA is the machine.
      expect(response.body).to include('6 contributors')
    end

    # Cases are editable in the admin and contributions ship in team.yml, so the two can be out
    # of step in production. A card with nobody credited says nothing rather than "0".
    it 'says nothing about a team where nobody is credited yet' do
      Case.create!(slug: 'brand-new', mark: '08', position: 8,
                   year: '2026', sector: { 'en' => 'new', 'uk' => 'нове' },
                   status: { 'en' => 'x', 'uk' => 'х' },
                   title: { 'en' => 'Brand new', 'uk' => 'Новий' },
                   tagline: { 'en' => 'x', 'uk' => 'х' }, role: { 'en' => 'x', 'uk' => 'х' },
                   plain_heading: { 'en' => 'x', 'uk' => 'х' },
                   engineering_heading: { 'en' => 'x', 'uk' => 'х' },
                   engineering_sub: { 'en' => 'x', 'uk' => 'х' },
                   scope_note: { 'en' => 'x', 'uk' => 'х' })

      get(action, params: { locale: 'en' })

      expect(response.body).to include('Brand new')
      expect(response.body).not_to include('0 contributors')
    end

    # The CV moved to /cv when six people appeared on this page. The nav still offers it, so
    # the assertion is about the page's own blocks rather than about the word.
    it 'is projects only' do
      get(action, params: { locale: 'en' })

      expect(response.body).not_to include('pf-career')
      expect(response.body).not_to include('pf-contact')
      expect(response.body).not_to include('cv-rows')
    end

    it 'renders the Ukrainian copy under the uk locale' do
      get(action, params: { locale: 'uk' })

      expect(response.body).to include('Роботи', 'ВЛАСНИЙ')
    end
  end

  describe 'GET #show' do
    let(:action) { :show }
    let(:params) { { locale: 'uk', slug: 'intelligence' } }

    it_behaves_like 'has http success'

    it 'renders both tracks' do
      get(action, params: params.merge(locale: 'en'))

      expect(response.body).to include('in plain words', 'for engineers')
    end

    it 'renders the scope note' do
      get(action, params: params.merge(locale: 'en'))

      expect(response.body).to include('Scope, honestly')
    end

    it 'renders inline markup from the content as markup' do
      get(action, params:)

      expect(response.body).to include('<code>pg_trgm</code>')
    end

    it 'drops a step in title size for long titles' do
      get(action, params:)

      expect(response.body).to include('wk-case__title is-long')
    end

    it 'keeps the full title size for short ones' do
      get(action, params: { slug: 'dna' })

      expect(response.body).not_to include('is-long')
    end

    # Between the engineering track and the pager, per the handoff.
    it 'ends with the people who built it, each linking at their page with the project in tow' do
      get(action, params: { locale: 'en', slug: 'dna' })

      expect(response.body).to include('wk-case__team')
      expect(response.body.scan('class="wk-teammate hover-row"').size).to eq(6)
      expect(response.body).to include("#{person_path('danyil', locale: 'en')}?from=dna")
      expect(response.body.index('wk-case__team')).to be > response.body.index('id="engineers"')
    end

    # A grid holding one lonely card reads as an unfinished page; this reads as a claim.
    it 'states solo work instead of drawing a team of one' do
      get(action, params: { locale: 'en', slug: 'intelligence' })

      expect(response.body).to include('Solo — the whole stack')
      expect(response.body).not_to include('wk-teammate')
    end

    it 'names whose team the other contributors were on solo commercial work' do
      get(action, params: { locale: 'en', slug: 'leads' })

      expect(response.body).to include('wk-solo__outside')
      expect(response.body).to include('38 contributors')
    end

    it 'wraps the pager at the end of the list' do
      get(action, params: { locale: 'uk', slug: 'rubycoin' })

      expect(response.body).to include(work_case_path(slug: 'intelligence'))
    end

    it 'raises for an unknown slug' do
      expect { get(action, params: { locale: 'uk', slug: 'nope' }) }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  # "Which cases do recruiters actually open" is the number the handoff says should decide the
  # order of /work (§9a), and nothing was counting it.
  describe 'view tracking', type: :request do
    include_context 'when carrierwave cleanup'

    it 'records one view per case' do
      expect { get work_case_path(slug: 'dna', locale: 'en'), headers: browser_headers }
        .to change { Ahoy::Event.where(name: 'Viewed Case').count }.by(1)
    end

    it 'stores the case id, so a renamed case keeps its history' do
      get work_case_path(slug: 'dna', locale: 'en'), headers: browser_headers

      event = Ahoy::Event.where(name: 'Viewed Case').last
      expect(event.properties['case_id']).to eq(Case.find_by!(slug: 'dna').id)
      expect(event.properties['slug']).to eq('dna')
    end

    it 'does not count the same reader twice inside the window' do
      get work_case_path(slug: 'dna', locale: 'en'), headers: browser_headers

      expect { get work_case_path(slug: 'dna', locale: 'en'), headers: browser_headers }
        .not_to(change { Ahoy::Event.where(name: 'Viewed Case').count })
    end

    it 'counts a different case in the same session' do
      get work_case_path(slug: 'dna', locale: 'en'), headers: browser_headers

      expect { get work_case_path(slug: 'leads', locale: 'en'), headers: browser_headers }
        .to change { Ahoy::Event.where(name: 'Viewed Case').count }.by(1)
    end
  end
end
