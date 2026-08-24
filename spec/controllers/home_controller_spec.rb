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

    # Nothing in the hero is invented: the eyebrow and the lede are the CV's own words.
    it 'builds the hero from the CV' do
      get root_path(locale: 'en')

      expect(response.body).to include(CVProfile.current[:name]['en'])
      expect(response.body).to include(ERB::Util.html_escape(I18n.with_locale(:en) { CVProfile.current.summary }))
    end

    it 'counts the published entries' do
      create(:post, :inactive)

      get root_path(locale: 'en')

      expect(response.body).to include(I18n.t('home.index.entries', count: Post.active.count, locale: :en))
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

    # There is no team data, and the handoff forbids placeholder people, so the crew column the
    # design drew beside the cards is absent — which is what §4 says to do without it.
    it 'carries no crew panel and no unconfirmed personal claims' do
      get root_path(locale: 'en')

      expect(response.body).not_to include('hm-crew')
      expect(response.body).not_to include('hm-notwork')
    end

    it 'renders the Ukrainian copy under the uk locale' do
      get root_path(locale: 'uk')

      expect(response.body).to include(I18n.t('home.index.headline', locale: :uk).first)
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
