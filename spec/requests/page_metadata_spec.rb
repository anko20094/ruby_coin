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
    it 'presents itself as the portfolio it is, not as a person' do
      get '/en/work'

      expect(content_of('og:type')).to eq('website')
      expect(response.body).not_to include('"@type":"ProfilePage"')
      expect(content_of('og:image')).to eq('http://www.example.com/og/site-en.png')
    end
  end

  describe '/cv' do
    it 'is the page that presents itself as a person' do
      get '/en/cv'

      expect(content_of('og:type')).to eq('profile')
      expect(response.body).to include('"@type":"ProfilePage"')
    end
  end

  # The schema read the CV directly, so every profile page described the owner.
  describe 'a person page' do
    it 'describes the person whose page it is' do
      get '/en/team/natalia'

      expect(response.body).to include('"name":"Nataliia Makarenko"')
      expect(response.body).not_to include('"name":"Danyil Shkoropad"')
    end

    it 'publishes no invented profile links for a placeholder record' do
      get '/en/team/mykhailo'

      expect(response.body).not_to include('sameAs')
    end

    # Everything here escapes on the way out, so a helper that hands back entities doubles them:
    # a role reading "product & clients" reached a share preview as "product &amp;amp; clients".
    it 'writes an ampersand once, in the tab and in a share preview' do
      get '/en/team/mykhailo'

      expect(response.body).to include('<title>Mykhail Yun · cofounder · product &amp; clients | rubyco.in</title>')
      expect(content_of('og:title')).to eq('Mykhail Yun · cofounder · product &amp; clients | rubyco.in')
      expect(response.body).not_to include('&amp;amp;')
    end

    # A schema.org Person record for a machine is the one place the joke would stop being
    # accurate.
    it 'does not call the automated reviewer a person' do
      get '/en/team/claude'

      expect(response.body).not_to include('"@type":"ProfilePage"')
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

  # Cards are baked by a rake task, and a case is added in the admin without a deploy.
  it 'falls back to the site card for a case whose own card has not been baked' do
    Case.find_by!(slug: 'dna').dup.update!(slug: 'brand-new', position: 99)

    get '/en/work/brand-new'

    expect(content_of('og:image')).to eq('http://www.example.com/og/site-en.png')
    expect(content_of('twitter:image')).to eq('http://www.example.com/og/site-en.png')
  end

  # A paginated or filtered list is a different list, not a copy of the first one; the person
  # page's ?from= is only the way the reader arrived.
  describe 'the canonical address' do
    it 'keeps the parameters that choose which list this is' do
      tag = create(:tag)

      get "/en/journal?tag_id=#{tag.id}&order=best"

      expect(response.body)
        .to include(%(<link href="http://www.example.com/en/journal?tag_id=#{tag.id}" rel="canonical" />))
      expect(response.body)
        .to include(%(<link href="http://www.example.com/uk/journal?tag_id=#{tag.id}" hreflang="uk" rel="alternate" />))
    end

    it 'does not make an address of a page that is not there, a first page or a tag that does not exist' do
      get '/en/journal?tag_id=999999&page=1'

      expect(response.body).to include('<link href="http://www.example.com/en/journal" rel="canonical" />')
    end

    it 'drops the ones that only say how the reader arrived' do
      get '/en/team/danyil?from=dna'

      expect(response.body).to include('<link href="http://www.example.com/en/team/danyil" rel="canonical" />')
    end
  end
end
