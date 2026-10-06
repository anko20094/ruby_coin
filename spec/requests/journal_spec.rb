# frozen_string_literal: true

require 'rails_helper'

describe 'the journal', type: :request do
  include_context 'when carrierwave cleanup'

  # Every request here asks for /en, so the fixtures have to be written in en too — Globalize
  # stores a title per locale and reads back nothing for the one it was not given.
  around { |example| I18n.with_locale(:en) { example.run } }

  let(:tag) { create(:tag, title: 'rails') }
  # An explicit title, not Faker's: a generated one can contain an apostrophe, which is
  # HTML-escaped in the rendered body and then does not match the raw string.
  let!(:post_record) { create(:post, status: 'active', tags: [tag], title: 'A findable entry') }

  describe 'GET /journal' do
    it 'renders the entry list on the theme layout' do
      get journal_path(locale: 'en')

      expect(response).to be_successful
      expect(response.body).to include('jn-entry')
      expect(response.body).to include(post_record.entry_label)
      expect(response.body).to include('rc-gem--anchor')
    end

    it 'lets J/K walk the rows and / find the search field' do
      get journal_path(locale: 'en')

      index = response.parsed_body.at_css('.jn-index[data-controller~="list-nav"]')
      expect(index['data-list-nav-item-value']).to eq('.jn-entry')
      expect(index.at_css('input.jn-search__input[data-list-nav-target="search"]')).to be_present
      expect(index.at_css('p.rc-keys[hidden]').text.squish).to eq('J K — navigate · / — search')
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

    describe 'more than one tag' do
      let(:design) { create(:tag, title: 'design') }
      let!(:both) { create(:post, status: 'active', tags: [tag, design], title: 'An entry under both tags') }
      let!(:design_only) { create(:post, status: 'active', tags: [design], title: 'An entry under design only') }

      def titles = response.parsed_body.css('.jn-entry__name').map(&:text)

      it 'lists only the entries carrying every selected tag' do
        get journal_path(locale: 'en', tag_id: [tag.id, design.id])

        expect(titles).to eq([both.title])
        expect(response.body).to include('entries carrying every selected tag')
      end

      it 'counts on each chip the entries that carry its tag' do
        get journal_path(locale: 'en')

        counts = response.parsed_body.css('.jn-filter a').to_h do |chip|
          [chip.children.first.text.strip, chip.at_css('.jn-filter__count')&.text]
        end
        expect(counts).to include('#rails' => '2', '#design' => '2')
      end

      it 'switches a tag on from a chip and keeps the one already on' do
        get journal_path(locale: 'en', tag_id: tag.id)

        chip = response.parsed_body.css('.jn-filter a').find { |link| link.text.start_with?('#design') }
        expect(chip['href']).to eq(journal_path(locale: 'en', tag_id: [tag.id, design.id].sort, order: 'new'))
      end

      it 'switches a tag off from its own chip, back to the single-tag address' do
        get journal_path(locale: 'en', tag_id: [tag.id, design.id])

        chip = response.parsed_body.css('.jn-filter a').find { |link| link.text.start_with?('#design') }
        expect(chip['aria-current']).to eq('true')
        expect(chip['href']).to eq(journal_path(locale: 'en', tag_id: tag.id, order: 'new'))
      end

      it 'draws the tags and the order as two labelled groups, the order one of three' do
        get journal_path(locale: 'en', order: 'oldest')

        groups = response.parsed_body.css('.jn-filter .jn-filter__group')
        expect(groups.map { |group| group.at_css('.jn-filter__label').text }).to eq(%w[filter show])
        options = groups.last.css('.jn-sort[role="group"] a.jn-sort__option')
        expect(options.size).to eq(Post::ORDER_TYPES.size)
        expect(options.select { |option| option['aria-current'] == 'true' }.map(&:text)).to eq(['oldest'])
      end

      it 'notes "every selected tag" only once two are on' do
        get journal_path(locale: 'en', tag_id: tag.id)

        expect(response.parsed_body.at_css('.jn-filter__note')).to be_nil
      end

      it 'says so when no entry carries them all' do
        get journal_path(locale: 'en', tag_id: [design.id, create(:tag, title: 'ops').id])

        expect(response.body).to include('no entries carry all of #design + #ops.')
      end

      it 'ignores what is not a tag id' do
        get '/en/journal?tag_id[x]=1'
        expect(response).to be_successful

        get '/en/journal?tag_id[]=nope'

        expect(response).to be_successful
        expect(titles).to include(post_record.title, both.title, design_only.title)
      end
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

  describe 'GET /journal, grouped by year' do
    before do
      post_record.update_columns(created_at: Time.zone.local(2026, 3, 1))
      create(:post, status: 'active', title: 'An entry from the year before', created_at: Time.zone.local(2025, 6, 1))
    end

    it 'heads each year with its number, its count and an anchor' do
      get journal_path(locale: 'en')

      headings = response.parsed_body.css('section.jn-year > h2.jn-year__heading')
      expect(headings.map { |heading| heading.text.squish }).to eq(['2026 · 1 entry', '2025 · 1 entry'])
      expect(response.parsed_body.at_css('section#year-2025')).to be_present
    end

    it 'turns the order round with the years' do
      get journal_path(locale: 'en', order: 'oldest')

      expect(response.parsed_body.css('.jn-year__number').map(&:text)).to eq(%w[2025 2026])
    end

    it 'demotes the rows to h3 under a year' do
      get journal_path(locale: 'en')

      expect(response.parsed_body.css('.jn-year h3.jn-entry__title').size).to eq(2)
    end

    it 'counts the whole year, not the page, when a year runs over two pages' do
      stub_const('JournalController::PER_PAGE', 1)

      get journal_path(locale: 'en', page: 1)

      expect(response.parsed_body.at_css('.jn-year__count').text).to include('1 entry')
      expect(response.parsed_body.css('.jn-year').size).to eq(1)
    end

    it 'does not group a ranking' do
      get journal_path(locale: 'en', order: 'best')

      expect(response.parsed_body.css('.jn-year')).to be_empty
      expect(response.parsed_body.css('h2.jn-entry__title').size).to eq(2)
    end
  end

  describe 'the view transition from a row to its entry' do
    it 'carries the row title\'s name for the entry\'s heading, and morphs no cover' do
      get journal_path(locale: 'en')
      row = response.parsed_body.at_css('a.jn-entry')
      expect(row.at_css('.jn-entry__title')['data-vt-name']).to eq("post-title-#{post_record.id}")
      expect(row.css('[style*="view-transition-name"]')).to be_empty

      get post_path(post_record, locale: 'en')
      expect(response.parsed_body.at_css('h1.jn-post__title')['style'])
        .to eq("view-transition-name: post-title-#{post_record.id}")
      expect(response.body).not_to include('post-cover-')
    end
  end

  describe 'GET /post/:id' do
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

    it 'draws a related entry without a cover as its stone, not an empty box' do
      # The cover is required, so a post goes without one when its file has gone missing.
      create(:post, status: 'active', tags: [tag], title: 'A related entry').update_columns(photo: nil)

      get post_path(locale: 'en', id: post_record.slug)

      cover = response.parsed_body.at_css('.jn-related__cover')
      expect(cover.at_css('img')).to be_nil
      expect(cover.at_css('.rc-cover-gem svg.rc-gem')).to be_present
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

    it 'draws only the neighbour there is, with nothing standing in for the other' do
      opening, latest = Post.active.order(:entry_number).to_a.values_at(0, -1)

      get post_path(locale: 'en', id: opening.slug)
      expect(response.parsed_body.css('.jn-steps > *').pluck('class')).to eq(['jn-step jn-step--next hover-row'])

      get post_path(locale: 'en', id: latest.slug)
      expect(response.parsed_body.css('.jn-steps > *').pluck('class')).to eq(['jn-step hover-row'])
    end

    it 'shows the neighbour’s cover beside it, or its stone when it has none' do
      second.update_columns(photo: nil)

      get post_path(locale: 'en', id: first.slug)

      step = response.parsed_body.at_css('.jn-step--next')
      expect(step.at_css('.jn-step__thumb img')).to be_nil
      expect(step.at_css('.jn-step__thumb .rc-cover-gem svg.rc-gem')).to be_present
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
      response.parsed_body.css('.jn-filter .rc-chips a').map { |chip| chip.text.squish }.grep(/\A#/)
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

      expect(chips('en')).to eq(['#rails 1'])
      expect(chips('uk')).to eq(['#rails 1', '#ukrainian 1'])
    end

    it 'is counted on the chips only in the language it is written in' do
      I18n.with_locale(:uk) do
        post_record.update!(title: 'Запис', subtitle: 'Підзаголовок', description: '<p>Текст</p>')
      end

      expect(chips('en')).to eq(['#rails 1'])
      expect(chips('uk')).to eq(['#rails 2'])
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
  describe 'GET /search' do
    let!(:hidden) { create(:post, status: 'inactive', title: 'A findable secret') }

    describe 'the results alone, for the journal\'s live search' do
      it 'answers with the fragment and its summary, without the layout' do
        get search_path(locale: 'en', query: 'findable', partial: 1)

        expect(response).to be_successful
        expect(response.body).not_to include('rc-nav')
        expect(response.parsed_body.at_css('.jn-results')['data-summary']).to eq('1 entry')
        expect(response.parsed_body.css('a.jn-entry').pluck('href')).to eq([post_path(post_record, locale: 'en')])
      end

      it 'says when nothing matched' do
        get search_path(locale: 'en', query: 'nothingmatchesthis', partial: 1)

        expect(response.parsed_body.at_css('.jn-results')['data-summary'])
          .to eq('Nothing matches “nothingmatchesthis”.')
      end

      it 'is the whole page when there is no query to answer' do
        get search_path(locale: 'en', partial: 1)

        expect(response.body).to include('rc-nav')
      end

      it 'is wired into the journal, with the list it replaces after its slot' do
        get journal_path(locale: 'en')

        form = response.parsed_body.at_css('form.jn-index__search[data-controller="live-search"]')
        expect(form['data-live-search-results-value']).to eq('journal-live')
        expect(form.at_css('[aria-live="polite"][data-live-search-target="status"]')).to be_present
        expect(form.at_css('input.jn-search__submit[type="submit"]')).to be_present
        expect(response.parsed_body.at_css('#journal-live[hidden] + .rc-keys, #journal-live[hidden] ~ .jn-entries'))
          .to be_present
      end
    end

    it 'gives the field its own clear button, hidden until script shows it' do
      [journal_path(locale: 'en'), search_path(locale: 'en', query: 'findable')].each do |path|
        get path

        box = response.parsed_body.at_css('.jn-search__box[data-controller="search-clear"]')
        expect(box.at_css('input[type="search"][data-search-clear-target="input"]')).to be_present
        clear = box.at_css('button.jn-search__clear[type="button"][hidden]')
        expect(clear['aria-label']).to eq('Clear the search')
        expect(clear['data-action']).to eq('search-clear#clear')
      end
    end

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
