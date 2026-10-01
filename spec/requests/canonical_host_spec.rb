# frozen_string_literal: true

require 'rails_helper'

# Every absolute URL a page prints is read by someone else's server — a crawler, a link preview,
# a feed reader — and a shared cache in front would keep whatever the first request taught it.
# Nothing may be built from the Host a client chose to send.
describe 'the canonical host', type: :request do
  include_context 'when carrierwave cleanup'
  include_context 'when the cases are imported'
  include_context 'when the cv is imported'

  let(:site) { 'https://rubyco.in' }
  let(:forged) { { 'Host' => 'evil.example', 'X-Forwarded-Host' => 'evil.example' } }
  let!(:post_record) { I18n.with_locale(:en) { create(:post, status: 'active', title: 'A listed entry') } }

  around do |example|
    options = Rails.application.config.x.canonical_url_options
    Rails.application.config.x.canonical_url_options = { host: 'rubyco.in', protocol: 'https' }

    example.run
  ensure
    Rails.application.config.x.canonical_url_options = options
  end

  it 'puts the canonical, the alternates and the share card on the configured host' do
    get '/en/work/dna', headers: forged

    expect(response.body).to include(%(<link href="#{site}/en/work/dna" rel="canonical" />))
    expect(response.body).to include(%(href="#{site}/uk/work/dna"))
    expect(response.body).to include(%(content="#{site}/og/dna-en.png"))
    expect(response.body).not_to include('evil.example')
  end

  it 'puts the feed link of every page on the configured host' do
    get '/en/journal', headers: forged

    expect(response.body).to include(%(href="#{site}/en/feed"))
    expect(response.body).not_to include('evil.example')
  end

  it 'writes the sitemap with the configured host' do
    get '/sitemap.xml', headers: forged

    expect(response.body).to include("<loc>#{site}/en/work</loc>", "<loc>#{site}/en/post/#{post_record.slug}</loc>")
    expect(response.body).not_to include('evil.example')
  end

  it 'writes the feed with the configured host' do
    get '/en/feed', headers: forged

    expect(response.body).to include("#{site}/en/post/#{post_record.slug}")
    expect(response.body).not_to include('evil.example')
  end

  it 'names the sitemap in robots.txt on the configured host' do
    get '/robots.txt', headers: forged

    expect(response.body).to include("Sitemap: #{site}/sitemap.xml")
  end
end
