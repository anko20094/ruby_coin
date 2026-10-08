# frozen_string_literal: true

require 'rails_helper'

# Mobility's fallbacks are off, so a post with no text in a language is a blank page there: a
# feed entry with an empty title, and a sitemap URL that a crawler fetches and finds nothing at.
describe 'discovery of a post written in one language', type: :request do
  include_context 'when carrierwave cleanup'
  include_context 'when the cases are imported'

  let!(:bilingual) do
    I18n.with_locale(:en) { create(:post, title: 'Written twice') }.tap do |post|
      I18n.with_locale(:uk) { post.update!(title: 'Написаний двічі', subtitle: 'Підзаголовок') }
    end
  end
  let!(:only_en) { I18n.with_locale(:en) { create(:post, title: 'English only') } }
  let!(:only_uk) { I18n.with_locale(:uk) { create(:post, title: 'Лише українською') } }

  def sitemap_urls
    get '/sitemap.xml'
    Nokogiri::XML(response.body).remove_namespaces!.css('url').to_h do |url|
      [url.at_css('loc').text, url.css('link').pluck('href')]
    end
  end

  def locs_of(urls, post) = urls.keys.grep(%r{/post/#{post.slug}\z})

  describe 'the sitemap' do
    it 'lists a post once in each language it is written in' do
      urls = sitemap_urls

      expect(locs_of(urls, bilingual)).to contain_exactly(
        "http://www.example.com/en/post/#{bilingual.slug}", "http://www.example.com/uk/post/#{bilingual.slug}"
      )
    end

    it 'lists a post written in English only under /en, and one written in Ukrainian only under /uk' do
      urls = sitemap_urls

      expect(locs_of(urls, only_en)).to eq(["http://www.example.com/en/post/#{only_en.slug}"])
      expect(locs_of(urls, only_uk)).to eq(["http://www.example.com/uk/post/#{only_uk.slug}"])
    end

    it 'cross-links only the languages that exist' do
      urls = sitemap_urls
      english_only = "http://www.example.com/en/post/#{only_en.slug}"

      expect(urls[english_only]).to eq([english_only])
      expect(urls["http://www.example.com/en/post/#{bilingual.slug}"]).to contain_exactly(
        "http://www.example.com/en/post/#{bilingual.slug}", "http://www.example.com/uk/post/#{bilingual.slug}"
      )
    end

    it 'still lists every page that exists in both languages in both, cross-linked' do
      urls = sitemap_urls

      expect(urls['http://www.example.com/en/work']).to contain_exactly(
        'http://www.example.com/en/work', 'http://www.example.com/uk/work'
      )
    end

    it 'does not answer 304 to a validator from before a post was translated' do
      get '/sitemap.xml'
      before_translating = response.headers['ETag']

      I18n.with_locale(:uk) { only_en.update!(title: 'Тепер і українською', subtitle: 'Підзаголовок') }
      get '/sitemap.xml', headers: { 'If-None-Match' => before_translating }

      expect(response).to have_http_status(:success)
      expect(response.body).to include("http://www.example.com/uk/post/#{only_en.slug}")
    end
  end

  describe 'the feed' do
    def entries(locale)
      get "/#{locale}/feed"
      Nokogiri::XML(response.body).remove_namespaces!.css('entry title').map(&:text)
    end

    it 'carries the posts that can be read in English, in English' do
      expect(entries('en')).to contain_exactly('Written twice', 'English only')
    end

    it 'carries the posts that can be read in Ukrainian, in Ukrainian' do
      expect(entries('uk')).to contain_exactly('Написаний двічі', 'Лише українською')
    end
  end

  describe 'the post page in a language the post is not written in' do
    it 'is not found for a reader, and is found in the language it is written in' do
      get "/uk/post/#{only_en.slug}"
      expect(response).to have_http_status(:not_found)

      get "/en/post/#{only_en.slug}"
      expect(response).to have_http_status(:ok)
    end

    it 'advertises only the languages the post is written in' do
      get "/en/post/#{only_en.slug}"

      expect(response.parsed_body.css('link[rel="alternate"][hreflang]').pluck('hreflang')).to eq(%w[en x-default])
      expect(response.parsed_body.css('.rc-nav__locale').pluck('hreflang')).to eq(%w[en])
    end

    it 'advertises both for a post written in both' do
      get "/en/post/#{bilingual.slug}"

      expect(response.parsed_body.css('.rc-nav__locale').pluck('hreflang')).to contain_exactly('en', 'uk')
    end

    it 'still opens for staff, who preview what is not published in a language yet' do
      sign_in create(:user, role: :admin)

      get "/uk/post/#{only_en.slug}"

      expect(response).to have_http_status(:ok)
    end
  end
end
