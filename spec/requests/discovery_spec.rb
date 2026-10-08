# frozen_string_literal: true

require 'rails_helper'

# The three files that tell the rest of the internet this site exists, none of which it had:
# a sitemap, a feed, and a robots.txt that names the sitemap.
describe 'discovery', type: :request do
  include_context 'when carrierwave cleanup'
  include_context 'when the cases are imported'

  let!(:post_record) { I18n.with_locale(:en) { create(:post, status: 'active', title: 'A listed entry') } }

  describe 'GET /sitemap.xml' do
    before { get '/sitemap.xml' }

    it 'is XML and answers without a locale in the path' do
      expect(response).to have_http_status(:success)
      expect(response.media_type).to eq('application/xml')
    end

    it 'lists every public page in both languages, cross-linked' do
      body = response.body

      I18nExtended::AVAILABLE_LOCALES.each do |locale|
        expect(body).to include("<loc>http://www.example.com/#{locale}/work</loc>")
        expect(body).to include("<loc>http://www.example.com/#{locale}/work/dna</loc>")
        expect(body).to include(%(hreflang="#{locale}"))
      end
      expect(body).to include("<loc>http://www.example.com/en/post/#{post_record.slug}</loc>")
    end

    it 'spells the home page the way its own canonical does, without a trailing slash' do
      expect(response.body).to include('<loc>http://www.example.com/en</loc>')
      expect(response.body).not_to include('<loc>http://www.example.com/en/</loc>')
    end

    # /cv and /studio are pages now, and every person has one of their own.
    it 'lists the pages that used to be redirects, and the roster' do
      expect(response.body).to include('<loc>http://www.example.com/en/cv</loc>')
      expect(response.body).to include('<loc>http://www.example.com/en/studio</loc>')
      expect(response.body).to include('<loc>http://www.example.com/uk/team</loc>')
      expect(response.body).to include('<loc>http://www.example.com/en/team/danyil</loc>')
      expect(response.body).to include('<loc>http://www.example.com/en/faq</loc>')
    end

    it 'leaves out the search screen, which robots.txt disallows' do
      expect(response.body).not_to include('/search<')
    end

    it 'never lists a hidden post' do
      hidden = I18n.with_locale(:en) { create(:post, status: 'inactive', title: 'Not listed') }

      get '/sitemap.xml'

      expect(response.body).not_to include(hidden.slug)
    end
  end

  describe 'GET /:locale/feed' do
    it 'is an Atom feed of the journal' do
      get '/en/feed'

      expect(response).to have_http_status(:success)
      expect(response.media_type).to eq('application/atom+xml')
      expect(response.body).to include('<title>A listed entry</title>')
      expect(response.body).to include(post_url(post_record, locale: 'en'))
    end

    it 'comes in the reader\'s language' do
      get '/uk/feed'

      expect(response.body).to include('xml:lang="uk"')
    end

    it 'never carries a hidden post' do
      hidden = I18n.with_locale(:en) { create(:post, status: 'inactive', title: 'Not published') }

      get '/en/feed'

      expect(response.body).not_to include(hidden.slug)
    end

    it 'is advertised from every page, so a reader does not have to know the URL' do
      get '/en/journal'

      expect(response.body).to include('type="application/atom+xml"')
    end
  end

  describe 'GET /robots.txt' do
    before { get '/robots.txt' }

    it 'points at the sitemap and keeps crawlers out of the admin' do
      expect(response.media_type).to eq('text/plain')
      expect(response.body).to include('Sitemap: http://www.example.com/sitemap.xml')
      expect(response.body).to include('Disallow: /management/')
    end

    it 'keeps them out of the search screen, which is an unbounded crawl space' do
      expect(response.body).to include('Disallow: /*/search')
    end

    # Every live address carries its locale, so the bare prefixes only match the redirect.
    it 'keeps them out of the admin, the sign-in screens and the API under both locales' do
      expect(response.body).to include('Disallow: /*/management/', 'Disallow: /*/users/', 'Disallow: /*/api/')
    end
  end

  # What a crawler is told it can skip must not outlive the list it was told about.
  describe 'validators' do
    let(:older) { I18n.with_locale(:en) { create(:post, status: 'active', title: 'The older one') } }

    before do
      older.update_columns(updated_at: 3.days.ago)
      post_record.update_columns(updated_at: 1.day.ago)
    end

    it 'expire the sitemap when a post that is not the newest is hidden' do
      get '/sitemap.xml'
      before_hiding = response.headers['ETag']

      I18n.with_locale(:en) { older.update!(status: 'inactive') }
      get '/sitemap.xml', headers: { 'If-None-Match' => before_hiding }

      expect(response).to have_http_status(:success)
      expect(response.body).not_to include(older.slug)
    end

    it 'expire the sitemap when a post is deleted' do
      get '/sitemap.xml'
      before_deleting = response.headers['ETag']

      older.destroy!
      get '/sitemap.xml', headers: { 'If-None-Match' => before_deleting }

      expect(response).to have_http_status(:success)
    end

    it 'expire the feed when a post that is not the newest is hidden' do
      get '/en/feed'
      before_hiding = response.headers['ETag']

      I18n.with_locale(:en) { older.update!(status: 'inactive') }
      get '/en/feed', headers: { 'If-None-Match' => before_hiding }

      expect(response).to have_http_status(:success)
      expect(response.body).not_to include(older.slug)
    end

    it 'expire the feed when a tag it carries is renamed' do
      tag = create(:tag, title: 'before')
      post_record.tags << tag
      get '/en/feed'
      before_renaming = response.headers['ETag']

      tag.update!(title: 'after', updated_at: 1.minute.from_now)
      get '/en/feed', headers: { 'If-None-Match' => before_renaming }

      expect(response).to have_http_status(:success)
      expect(response.body).to include('term="after"')
    end

    it 'answer an unchanged document with 304' do
      get '/sitemap.xml'

      get '/sitemap.xml', headers: { 'If-None-Match' => response.headers['ETag'] }

      expect(response).to have_http_status(:not_modified)
    end
  end

  # These are held by shared caches, which would hand the next reader the previous one's cookie.
  describe 'cookies' do
    ['/sitemap.xml', '/robots.txt', '/en/feed'].each do |path|
      it "sets none on #{path}, which is public" do
        get path

        expect(response.headers['Cache-Control']).to include('public')
        expect(response.headers['Set-Cookie']).to be_nil
      end
    end
  end
end
