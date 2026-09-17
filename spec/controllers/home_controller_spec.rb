# frozen_string_literal: true

require 'rails_helper'

describe HomeController, type: :request do
  include_context 'when the cases are imported'
  include_context 'when the cv is imported'

  let!(:latest) do
    I18n.with_locale(:en) { create(:post, status: 'active', title: 'The newest entry', subtitle: 'Its lede') }
  end

  describe 'GET #index' do
    it 'renders the home page on the theme layout' do
      get root_path(locale: 'en')

      expect(response).to be_successful
      expect(response.body).to include('hm-hero')
      expect(response.body).to include('rc-footer')
    end

    # The nav is the reason this page mattered most: without it the redesigned sections were
    # only reachable by typing the URL.
    it 'links to every section of the site' do
      get root_path(locale: 'en')

      expect(response.body).to include(journal_path(locale: 'en'), work_path(locale: 'en'),
                                       contact_path(locale: 'en'))
    end

    # The hero is the studio speaking, and every number in it is counted rather than typed.
    it 'counts the projects, the people and the year the oldest project started' do
      get root_path(locale: 'en')

      expect(response.body).to include("#{Case.count} products · #{Team.crew.size} of us · shipping since 2022")
    end

    it 'carries the headline and both halves of the lede' do
      get root_path(locale: 'en')

      expect(response.body).to include(I18n.t('home.index.headline_lead', locale: :en))
      expect(response.body).to include(I18n.t('home.index.headline_mark', locale: :en))
      # The sentence a competitor's site will not print, and the reason the good numbers above
      # it are believable.
      expect(response.body).to include('outage that lasted eleven hours')
    end

    it 'shows the featured post when one is flagged, and the newest otherwise' do
      get root_path(locale: 'en')
      expect(response.body).to include('The newest entry')

      featured = I18n.with_locale(:en) { create(:post, :main_post, status: 'active', title: 'The featured one') }

      get root_path(locale: 'en')
      expect(response.body).to include('The featured one')
      expect(featured.reload).to be_main_post
    end

    it 'shows the first three cases and nothing more' do
      get root_path(locale: 'en')

      expect(response.body.scan('class="hm-card"').size).to eq(HomeController::RECENT_CASES)
      expect(response.body).to include(work_case_path(slug: 'intelligence', locale: 'en'))
    end

    # The third surface showing the roster, and it reads the same file as /studio and /team.
    it 'shows the crew, each row linking at that person' do
      get root_path(locale: 'en')

      expect(response.body.scan('class="hm-crew__row hover-row"').size).to eq(Team.crew.size)
      expect(response.body).to include(person_path('claude', locale: 'en'))
    end

    it 'counts the humans on the roster separately, because one of them is not' do
      get root_path(locale: 'en')

      humans = Team.crew.count { |person| !person.machine? }

      expect(response.body).to include("#{Team.crew.size} of us · #{humans} of them human")
    end

    # It used to be one five-column strip here, attributed to the studio as a whole. A studio
    # does not play volleyball on Tuesdays — one specific person does.
    it 'carries no not-work strip: that lives on a person page now' do
      get root_path(locale: 'en')

      expect(response.body).not_to include('tm-notwork')
    end

    it 'renders the Ukrainian copy under the uk locale' do
      get root_path(locale: 'uk')

      expect(response.body).to include(I18n.t('home.index.headline_lead', locale: :uk))
      expect(response.body).to include("нас #{Team.crew.size}")
    end
  end

  # The old front page was the article stream; these query strings were its pagination and tag
  # filter. They are gone for good, so they move to /journal permanently.
  describe 'the stream URLs the old home page had' do
    it 'sends ?page= to the journal' do
      get root_path(locale: 'en', page: 3)

      expect(response).to have_http_status(:moved_permanently)
      expect(response).to redirect_to(journal_path(locale: 'en', page: '3'))
    end

    it 'carries a tag filter across' do
      get root_path(locale: 'en', tag_ids: ['7'])

      expect(response).to redirect_to(journal_path(locale: 'en', tag_id: '7'))
    end

    it 'carries the ordering across' do
      get root_path(locale: 'uk', order: 'best')

      expect(response).to redirect_to(journal_path(locale: 'uk', order: 'best'))
    end

    it 'leaves the home page alone without them' do
      get root_path(locale: 'en')

      expect(response).to have_http_status(:success)
    end
  end
end
