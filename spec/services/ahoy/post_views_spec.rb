# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Post view tracking', type: :request do
  include_context 'when carrierwave cleanup'

  around { |example| I18n.with_locale(:en) { example.run } }

  let!(:unread) { create(:post, title: 'Nobody opened this') }
  let!(:read) { create(:post, title: 'Somebody did', created_at: 1.week.ago) }

  describe 'the events the journal writes' do
    it 'are the ones Post.best ranks by' do
      expect(Post.best.first).to eq(unread)

      get post_path(locale: 'en', id: read.slug), headers: browser_headers

      expect(Post.best.first).to eq(read)
      expect(Post.best.first.attributes['views_count']).to eq(1)
    end

    it 'are the ones the statistics count' do
      get post_path(locale: 'en', id: read.slug), headers: browser_headers

      expect(Statistics::PostViewsQuery.call).to eq([[read, 1]])
    end
  end

  describe 'a crawler' do
    it 'is not counted' do
      get post_path(locale: 'en', id: read.slug),
          headers: { 'HTTP_USER_AGENT' => 'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)' }

      expect(response).to be_successful
      expect([Ahoy::Visit.count, Ahoy::Event.count]).to eq([0, 0])
    end

    it 'is not counted when it sends no User-Agent at all' do
      get post_path(locale: 'en', id: read.slug)

      expect(response).to be_successful
      expect([Ahoy::Visit.count, Ahoy::Event.count]).to eq([0, 0])
    end
  end

  # One session key per subject. The cookie holding them is 4 KB, and the 65th distinct entry
  # used to make the response a 500.
  describe 'a long reading session' do
    it 'never outgrows its cookie' do
      70.times do
        get post_path(locale: 'en', id: create(:post).slug), headers: browser_headers

        expect(response).to be_successful
      end

      expect(Ahoy::Event.where(name: 'Viewed Post').count).to eq(70)
    end
  end
end
