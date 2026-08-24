# frozen_string_literal: true

require 'rails_helper'

# The site exists to be linked to. Before this every one of those links unfurled as a grey
# rectangle: no description, no Open Graph, no Twitter card, no canonical, no hreflang.
describe 'page metadata', type: :request do
  include_context 'when carrierwave cleanup'
  include_context 'when the cases are imported'
  include_context 'when the cv is imported'

  def meta(name)
    response.body[/<meta [^>]*(?:property|name)="#{Regexp.escape(name)}"[^>]*>/]
  end

  def content_of(name)
    meta(name)&.[](/content="([^"]*)"/, 1)
  end

  describe 'a case page' do
    before { get '/en/work/dna' }

    it 'unfurls with its own card, not a grey nothing' do
      expect(content_of('og:image')).to eq('http://www.example.com/og/dna-en.png')
      expect(content_of('og:image:width')).to eq('1200')
      expect(content_of('twitter:card')).to eq('summary_large_image')
    end

    it 'describes itself with the case tagline' do
      expect(content_of('og:description')).to include('Telegram channels')
      expect(content_of('description')).to eq(content_of('og:description'))
    end

    it 'says which page it is and which language, in both directions' do
      expect(response.body).to include('<link href="http://www.example.com/en/work/dna" rel="canonical" />')
      expect(response.body).to include('hreflang="uk"')
      expect(response.body).to include('hreflang="x-default"')
    end

    it 'carries structured data a search engine can read' do
      expect(response.body).to include('application/ld+json')
      expect(response.body).to include('"@type":"BlogPosting"')
    end

    it 'has a title that says more than the project mark' do
      expect(response.body).to include('<title>DNA · content automation | rubyco.in</title>')
    end
  end

  describe 'a journal post' do
    let!(:post_record) do
      I18n.with_locale(:en) { create(:post, status: 'active', title: 'An entry', subtitle: 'Its lede') }
    end

    # The handoff asks journal posts to unfurl with their existing cover image.
    it 'unfurls with its own cover' do
      get post_path(post_record, locale: 'en')

      expect(content_of('og:image')).to include(post_record.photo.medium.url)
      expect(content_of('og:description')).to eq('Its lede')
      expect(content_of('og:type')).to eq('article')
      expect(content_of('article:published_time')).to eq(post_record.created_at.iso8601)
    end
  end

  describe '/work' do
    it 'presents itself as a person, because that is what it is' do
      get '/en/work'

      expect(content_of('og:type')).to eq('profile')
      expect(response.body).to include('"@type":"ProfilePage"')
      expect(content_of('og:image')).to eq('http://www.example.com/og/site-en.png')
    end
  end

  it 'gives the Ukrainian pages the Ukrainian card and locale' do
    get '/uk/work/dna'

    expect(content_of('og:image')).to eq('http://www.example.com/og/dna-uk.png')
    expect(content_of('og:locale')).to eq('uk_UA')
  end

  it 'ships a card file for every case in both languages' do
    Case.pluck(:slug).each do |slug|
      I18nExtended::AVAILABLE_LOCALES.each do |locale|
        card = Rails.public_path.join("og/#{slug}-#{locale}.png")

        expect(card).to exist, "missing share card for #{slug} in #{locale}"
      end
    end
  end
end
