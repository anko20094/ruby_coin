# frozen_string_literal: true

require 'rails_helper'

describe JournalController, type: :request do
  include_context 'when carrierwave cleanup'

  # Every request here asks for /en, so the fixtures have to be written in en too — Globalize
  # stores a title per locale and reads back nothing for the one it was not given.
  around { |example| I18n.with_locale(:en) { example.run } }

  let(:tag) { create(:tag, title: 'rails') }
  let!(:post_record) { create(:post, status: 'active', tags: [tag]) }

  describe 'GET #index' do
    it 'renders the entry list on the theme layout' do
      get journal_path(locale: 'en')

      expect(response).to be_successful
      expect(response.body).to include('jn-entry')
      expect(response.body).to include(post_record.entry_label)
      expect(response.body).to include('rc-gem--anchor')
    end

    it 'counts the entries in the eyebrow' do
      get journal_path(locale: 'en')

      expect(response.body).to include('1 entry')
    end

    it 'filters by a single tag' do
      other = create(:post, status: 'active', tags: [create(:tag, title: 'design')])

      get journal_path(locale: 'en', tag_id: tag.id)

      expect(response.body).to include(post_record.title)
      expect(response.body).not_to include(other.title)
    end

    it 'shows the empty state when a tag has no entries' do
      empty_tag = create(:tag, title: 'ops')

      get journal_path(locale: 'en', tag_id: empty_tag.id)

      expect(response.body).to include('no entries for #ops.')
    end

    it 'accepts the best ordering without breaking pagination' do
      get journal_path(locale: 'en', order: 'best')

      expect(response).to be_successful
    end

    it 'ignores an unknown ordering rather than failing' do
      get journal_path(locale: 'en', order: 'sideways')

      expect(response).to be_successful
      expect(response.body).to include('jn-entry')
    end
  end

  describe 'GET #show' do
    it 'renders the post at the reading measure with its lede and number' do
      get post_path(locale: 'en', id: post_record.slug)

      expect(response).to be_successful
      expect(response.body).to include('jn-post')
      expect(response.body).to include('jn-body__lede')
      expect(response.body).to include(post_record.entry_label)
    end

    it 'renders the body from Action Text' do
      post_record.update!(description_en: '<p>A sentence only this test writes.</p>')

      get post_path(locale: 'en', id: post_record.slug)

      expect(response.body).to include('A sentence only this test writes.')
    end

    it 'highlights a code block server-side and names the language' do
      post_record.update!(description_en: '<pre><code class="language-ruby">def call; end</code></pre>')

      get post_path(locale: 'en', id: post_record.slug)

      expect(response.body).to include('jn-code__lang">ruby')
      expect(response.body).to include('class="k"')
    end

    it 'shows a related row when other posts share a tag' do
      related = create(:post, status: 'active', tags: [tag])

      get post_path(locale: 'en', id: post_record.slug)

      expect(response.body).to include('jn-related')
      expect(response.body).to include(related.title)
    end

    it 'redirects to the journal when the slug resolves to nothing' do
      get post_path(locale: 'en', id: 'never-existed')

      expect(response).to redirect_to(journal_path(locale: 'en'))
    end

    it 'still resolves a slug the post used to have' do
      old_slug = post_record.slug
      post_record.update!(slug: 'a-brand-new-slug')

      get post_path(locale: 'en', id: old_slug)

      expect(response).to be_successful
    end
  end

  # Ahoy tracking lives on the post page, which moved here from home#show.
  describe 'view tracking' do
    it 'tracks the first visit' do
      expect { get post_path(locale: 'en', id: post_record.slug) }
        .to change(Ahoy::Visit, :count).by(1)
        .and change(Ahoy::Event, :count).by(1)
    end

    it 'does not track the same post twice within three hours' do
      get post_path(locale: 'en', id: post_record.slug)

      expect { get post_path(locale: 'en', id: post_record.slug) }.not_to change(Ahoy::Event, :count)
    end

    it 'tracks again after 24 hours' do
      get post_path(locale: 'en', id: post_record.slug)
      allow(Time).to receive(:now).and_return(25.hours.from_now)

      expect { get post_path(locale: 'en', id: post_record.slug) }.to change(Ahoy::Event, :count).by(1)
    end

    it 'tracks two different posts within the same window' do
      second = create(:post, status: 'active')

      get post_path(locale: 'en', id: post_record.slug)

      expect { get post_path(locale: 'en', id: second.slug) }.to change(Ahoy::Event, :count).by(1)
    end
  end
end
