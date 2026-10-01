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

    it 'keeps every tag of an entry on a list filtered by one of them' do
      post_record.tags << create(:tag, title: 'design')

      get journal_path(locale: 'en', tag_id: tag.id)

      expect(response.parsed_body.at_css('.jn-entry__tags').text).to include('#rails', '#design')
    end

    it 'lists an entry once however many of its tags match' do
      post_record.tags << create(:tag, title: 'design')

      get journal_path(locale: 'en', tag_id: tag.id)

      expect(response.parsed_body.css('.jn-entry').size).to eq(1)
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

    it 'loads the related entries in one query rather than asking first whether there are any' do
      create(:post, status: 'active', tags: [tag], title: 'A related entry')
      related_queries = []
      collect = ->(*, payload) { related_queries << payload[:sql] if payload[:sql].include?('overlap') }

      ActiveSupport::Notifications.subscribed(collect, 'sql.active_record') do
        get post_path(locale: 'en', id: post_record.slug)
      end

      expect(related_queries.size).to eq(1)
    end

    it 'answers 404 when the slug resolves to nothing' do
      get post_path(locale: 'en', id: 'never-existed')

      expect(response).to have_http_status(:not_found)
    end

    it 'answers 404 for a slug with a NUL byte in it' do
      get '/en/post/a%00b'

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

    context 'when the address is not the one the post has now' do
      let!(:old_slug) { post_record.slug }

      before { post_record.update!(slug: 'a-brand-new-slug') }

      it 'sends a slug the post used to have to the current one, once and for good' do
        get post_path(locale: 'en', id: old_slug)

        expect(response).to have_http_status(:moved_permanently)
        expect(response).to redirect_to(post_path(locale: 'en', id: 'a-brand-new-slug'))
      end

      it 'sends the numeric id the same way' do
        get post_path(locale: 'en', id: post_record.id)

        expect(response).to have_http_status(:moved_permanently)
        expect(response).to redirect_to(post_path(locale: 'en', id: 'a-brand-new-slug'))
      end

      it 'keeps the language of the address it was asked at' do
        I18n.with_locale(:uk) { post_record.update!(title: 'Старий заголовок', subtitle: 'Підзаголовок') }

        get post_path(locale: 'uk', id: old_slug)

        expect(response).to redirect_to(post_path(locale: 'uk', id: 'a-brand-new-slug'))
      end

      it 'answers only at the current slug' do
        get post_path(locale: 'en', id: 'a-brand-new-slug')

        expect(response).to be_successful
      end

      it 'does not count a visit to an address it is about to redirect' do
        expect { get post_path(locale: 'en', id: old_slug), headers: browser_headers }
          .not_to change(Ahoy::Event, :count)
      end

      it 'redirects a staff preview of a hidden post the same way, and then serves it' do
        post_record.update!(status: 'inactive')
        sign_in create(:user, role: :admin)

        get post_path(locale: 'en', id: post_record.id)
        expect(response).to redirect_to(post_path(locale: 'en', id: 'a-brand-new-slug'))

        follow_redirect!
        expect(response).to be_successful
      end

      it 'still answers 404 for a hidden post to a reader who asks by id' do
        post_record.update!(status: 'inactive')

        get post_path(locale: 'en', id: post_record.id)

        expect(response).to have_http_status(:not_found)
      end
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

  describe 'an entry with no text in the reader\'s language' do
    let!(:only_uk) do
      I18n.with_locale(:uk) { create(:post, status: 'active', tags: [tag], title: 'A findable Ukrainian-only entry') }
    end

    def listed(locale, **)
      get(journal_path(locale:, **))
      response.parsed_body.css('a.jn-entry').pluck('href')
    end

    def chips(locale)
      get journal_path(locale:)
      response.parsed_body.css('.jn-filter .rc-chips a').map(&:text).grep(/\A#/)
    end

    it 'is left off the list and out of the count' do
      expect(listed('en')).to eq([post_path(post_record, locale: 'en')])
      expect(response.body).to include('1 entry')
    end

    it 'is listed in the language it is written in' do
      expect(listed('uk')).to eq([post_path(only_uk, locale: 'uk')])
    end

    it 'does not leave a tag on offer that only it carries' do
      only_uk.tags << create(:tag, title: 'ukrainian')

      expect(chips('en')).to eq(['#rails'])
      expect(chips('uk')).to eq(%w[#rails #ukrainian])
    end

    it 'is not a search result' do
      get search_path(locale: 'en', query: 'findable')

      expect(response.parsed_body.css('a.jn-entry').pluck('href')).to eq([post_path(post_record, locale: 'en')])
    end

    it 'is not offered as related, or as the next entry' do
      get post_path(locale: 'en', id: post_record.slug)

      expect(response.body).not_to include(post_path(locale: 'en', id: only_uk.slug))
    end

    it 'opens in the language it is written in and is not found in the other' do
      get post_path(locale: 'uk', id: only_uk.slug)
      expect(response).to be_successful

      get post_path(locale: 'en', id: only_uk.slug)
      expect(response).to have_http_status(:not_found)
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

    it 'loads the results in one query rather than asking first whether there are any' do
      names = []
      collect = ->(*, payload) { names << payload[:name] }

      ActiveSupport::Notifications.subscribed(collect, 'sql.active_record') do
        get search_path(locale: 'en', query: 'findable')
      end

      expect(names).to include('Post Load')
      expect(names).not_to include('Post Exists?')
    end

    it 'answers a query with a NUL byte as if it were not there' do
      get search_path(locale: 'en', query: "find\0able")

      expect(response).to be_successful
      expect(response.body).to include(post_record.title)
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

    it 'does not count a staff member proofreading a hidden post towards the ranking' do
      post_record.update!(status: 'inactive')
      sign_in create(:user, role: :admin)

      expect { get post_path(locale: 'en', id: post_record.slug), headers: browser_headers }
        .not_to change(Ahoy::Event, :count)
    end

    it 'does not count a staff member reading a published post either' do
      sign_in create(:user, role: :moderator)

      expect { get post_path(locale: 'en', id: post_record.slug), headers: browser_headers }
        .not_to change(Ahoy::Event, :count)
    end

    it 'tracks two different posts within the same window' do
      second = create(:post, status: 'active')

      get post_path(locale: 'en', id: post_record.slug), headers: browser_headers

      expect { get post_path(locale: 'en', id: second.slug), headers: browser_headers }
        .to change(Ahoy::Event, :count).by(1)
    end
  end
end
