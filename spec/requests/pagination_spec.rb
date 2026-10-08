# frozen_string_literal: true

require 'rails_helper'

describe 'the pagers', type: :request do
  include_context 'when carrierwave cleanup'

  around { |example| I18n.with_locale(:en) { example.run } }

  before do
    stub_const('JournalController::PER_PAGE', 2)
    stub_const('Management::PostsController::PER_PAGE', 2)
  end

  let!(:posts) { Array.new(5) { |index| create(:post, title: "Pager entry #{index}") } }

  def pager_hrefs(css)
    response.parsed_body.css("#{css} a").pluck('href')
  end

  describe 'the journal' do
    it 'offers only the next page on the first one' do
      get journal_path(locale: 'en')

      expect(response).to be_successful
      expect(pager_hrefs('nav.jn-pager')).to eq([journal_path(locale: 'en', order: 'new', page: 2, anchor: 'entries')])
    end

    it 'offers both neighbours on a page in the middle' do
      get journal_path(locale: 'en', page: 2)

      expect(response).to be_successful
      expect(pager_hrefs('nav.jn-pager')).to eq(
        [
          journal_path(locale: 'en', order: 'new', page: 1, anchor: 'entries'),
          journal_path(locale: 'en', order: 'new', page: 3, anchor: 'entries')
        ]
      )
    end

    it 'offers only the previous page on the last one' do
      get journal_path(locale: 'en', page: 3)

      expect(response).to be_successful
      expect(pager_hrefs('nav.jn-pager')).to eq([journal_path(locale: 'en', order: 'new', page: 2, anchor: 'entries')])
    end

    it 'pages the best ordering and a tag filter too' do
      tag = create(:tag, title: 'rails')
      posts.each { |post| post.tags << tag }

      get journal_path(locale: 'en', order: 'best', tag_id: tag.id, page: 2)

      expect(response).to be_successful
      expect(pager_hrefs('nav.jn-pager'))
        .to include(journal_path(locale: 'en', order: 'best', tag_id: tag.id, page: 3, anchor: 'entries'))
    end

    it 'sends a page past the end to the last one' do
      get journal_path(locale: 'en', order: 'oldest', page: 9)

      expect(response).to redirect_to(journal_path(locale: 'en', order: 'oldest', page: 3))
    end

    it 'sends a page too large for the database to the last one' do
      get journal_path(locale: 'en', page: '99999999999999999999')

      expect(response).to redirect_to(journal_path(locale: 'en', page: 3))
    end

    it 'shows the empty state on the first page of nothing, not a redirect' do
      Post.find_each(&:destroy)

      get journal_path(locale: 'en')

      expect(response).to be_successful
      expect(response.parsed_body.at_css('.jn-empty')).to be_present
    end
  end

  describe 'the search' do
    it 'offers only the next page on the first one' do
      get search_path(locale: 'en', query: 'pager')

      expect(response).to be_successful
      expect(pager_hrefs('nav.jn-pager')).to eq([search_path(locale: 'en', query: 'pager', search_in: 'all', page: 2)])
    end

    it 'offers both neighbours on a page in the middle' do
      get search_path(locale: 'en', query: 'pager', page: 2)

      expect(response).to be_successful
      expect(pager_hrefs('nav.jn-pager')).to eq(
        [
          search_path(locale: 'en', query: 'pager', search_in: 'all', page: 1),
          search_path(locale: 'en', query: 'pager', search_in: 'all', page: 3)
        ]
      )
    end

    it 'sends a page past the end to the last one, keeping the query' do
      get search_path(locale: 'en', query: 'pager', search_in: 'title', page: '99999999999999999999')

      expect(response).to redirect_to(search_path(locale: 'en', query: 'pager', search_in: 'title', page: 3))
    end
  end

  describe 'the admin list' do
    before { sign_in create(:user, role: :admin) }

    it 'offers only the next page on the first one' do
      get management_posts_path(locale: 'en')

      expect(response).to be_successful
      expect(pager_hrefs('nav.mg-pager')).to eq([management_posts_path(locale: 'en', page: 2)])
    end

    it 'offers both neighbours on a page in the middle' do
      get management_posts_path(locale: 'en', page: 2)

      expect(response).to be_successful
      expect(pager_hrefs('nav.mg-pager')).to eq(
        [management_posts_path(locale: 'en', page: 1), management_posts_path(locale: 'en', page: 3)]
      )
    end
  end
end
