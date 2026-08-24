# frozen_string_literal: true

require 'rails_helper'

describe JournalController, type: :request do
  include_context 'when carrierwave cleanup'

  # Every request here asks for /en, so the fixtures have to be written in en too — Globalize
  # stores a title per locale and reads back nothing for the one it was not given.
  around { |example| I18n.with_locale(:en) { example.run } }

  let(:tag) { create(:tag, title: 'rails') }
  # An explicit title, not Faker's: a generated one can contain an apostrophe, which is
  # HTML-escaped in the rendered body and then does not match the raw string.
  let!(:post_record) { create(:post, status: 'active', tags: [tag], title: 'A findable entry') }

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
      other = create(:post, status: 'active', tags: [create(:tag, title: 'design')],
                            title: 'An entry under another tag')

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
      related = create(:post, status: 'active', tags: [tag], title: 'A related entry')

      get post_path(locale: 'en', id: post_record.slug)

      expect(response.body).to include('jn-related')
      expect(response.body).to include(related.title)
    end

    it 'answers 404 when the slug resolves to nothing' do
      get post_path(locale: 'en', id: 'never-existed')

      expect(response).to have_http_status(:not_found)
    end

    it 'answers 404 for a hidden post rather than serving it' do
      post_record.update!(status: 'inactive')

      get post_path(locale: 'en', id: post_record.slug)

      expect(response).to have_http_status(:not_found)
    end

    it 'lets a signed-in staff member preview a hidden post' do
      post_record.update!(status: 'inactive')
      sign_in create(:user, role: :admin)

      get post_path(locale: 'en', id: post_record.slug)

      expect(response).to be_successful
      expect(response.body).to include(post_record.title)
    end

    it 'still resolves a slug the post used to have' do
      old_slug = post_record.slug
      post_record.update!(slug: 'a-brand-new-slug')

      get post_path(locale: 'en', id: old_slug)

      expect(response).to be_successful
    end
  end

  # The journal is a numbered series and had no way to be read as one: every entry's only
  # exits were back to the index and a tag-similarity row.
  describe 'reading the series in order' do
    let!(:first) { I18n.with_locale(:en) { create(:post, status: 'active', title: 'The first one') } }
    let!(:second) { I18n.with_locale(:en) { create(:post, status: 'active', title: 'The second one') } }

    it 'links an entry to the one before and the one after it' do
      get post_path(locale: 'en', id: first.slug)

      expect(response.body).to include(post_path(locale: 'en', id: second.slug))
      expect(response.body).to include('jn-steps')
    end

    it 'orders by the printed series number, not by publication date' do
      second.update_columns(created_at: 5.years.ago)

      get post_path(locale: 'en', id: second.slug)

      expect(response.body).to include(first.title)
    end

    it 'never steps into a hidden entry' do
      second.update!(status: 'inactive')

      get post_path(locale: 'en', id: first.slug)

      expect(response.body).not_to include(second.title)
    end

    it 'offers to read from the beginning' do
      get journal_path(locale: 'en')

      expect(response.body).to include(journal_path(locale: 'en', order: 'oldest'))
    end

    it 'lists the oldest entry first when asked' do
      get journal_path(locale: 'en', order: 'oldest')

      expect(response.body.index(post_record.title)).to be < response.body.index(second.title)
    end
  end

  # /search moved off the old Bootstrap layout and onto the journal. It kept its URL, because
  # the URL is indexed, but it was a screen nothing in the redesigned nav pointed at.
  describe 'GET #search' do
    let!(:hidden) { create(:post, status: 'inactive', title: 'A findable secret') }

    it 'renders on the theme layout, like the rest of the journal' do
      get search_path(locale: 'en', query: 'findable')

      expect(response).to be_successful
      expect(response.body).to include('jn-search')
      expect(response.body).to include('rc-nav')
      expect(response.body).not_to include('search-page')
    end

    it 'finds a published entry' do
      get search_path(locale: 'en', query: 'findable')

      expect(response.body).to include(post_record.title)
    end

    it 'never returns a hidden one' do
      get search_path(locale: 'en', query: 'findable')

      expect(response.body).not_to include(hidden.title)
    end

    it 'asks for a query rather than listing everything' do
      get search_path(locale: 'en')

      expect(response).to be_successful
      expect(response.body).to include(I18n.t('journal.search.prompt', locale: :en))
    end

    it 'says so when nothing matches' do
      get search_path(locale: 'en', query: 'zzzzznotathing')

      expect(response.body).to include('zzzzznotathing')
      expect(response.body).to include(journal_path(locale: 'en'))
    end

    it 'falls back to searching everywhere when asked for a field it does not have' do
      get search_path(locale: 'en', query: 'findable', search_in: 'nonsense')

      expect(response).to be_successful
      expect(response.body).to include(post_record.title)
    end

    it 'is reachable from the journal index' do
      get journal_path(locale: 'en')

      expect(response.body).to include(search_path(locale: 'en'))
    end
  end

  # Ahoy tracking lives on the post page, which moved here from home#show.
  describe 'view tracking' do
    it 'tracks the first visit' do
      expect { get post_path(locale: 'en', id: post_record.slug), headers: browser_headers }
        .to change(Ahoy::Visit, :count).by(1)
        .and change(Ahoy::Event, :count).by(1)
    end

    it 'does not track the same post twice within three hours' do
      get post_path(locale: 'en', id: post_record.slug), headers: browser_headers

      expect { get post_path(locale: 'en', id: post_record.slug), headers: browser_headers }
        .not_to change(Ahoy::Event, :count)
    end

    it 'tracks again after 24 hours' do
      get post_path(locale: 'en', id: post_record.slug), headers: browser_headers
      allow(Time).to receive(:now).and_return(25.hours.from_now)

      expect { get post_path(locale: 'en', id: post_record.slug), headers: browser_headers }
        .to change(Ahoy::Event, :count).by(1)
    end

    it 'tracks two different posts within the same window' do
      second = create(:post, status: 'active')

      get post_path(locale: 'en', id: post_record.slug), headers: browser_headers

      expect { get post_path(locale: 'en', id: second.slug), headers: browser_headers }
        .to change(Ahoy::Event, :count).by(1)
    end
  end
end
