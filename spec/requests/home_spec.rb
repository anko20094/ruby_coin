# frozen_string_literal: true

require 'rails_helper'

describe 'the home page', type: :request do
  include_context 'when the cases are imported'

  let!(:latest) do
    I18n.with_locale(:en) { create(:post, status: 'active', title: 'The newest entry', subtitle: 'Its lede') }
  end

  describe 'GET /' do
    it 'renders the home page on the theme layout' do
      get root_path(locale: 'en')

      expect(response).to be_successful
      expect(response.body).to include('hm-hero')
      expect(response.body).to include('rc-footer')
    end

    # The nav is the reason this page mattered most: without it the redesigned sections were
    # only reachable by typing the URL.
    it 'links to every section of the site' do
      get root_path(locale: 'en')

      expect(response.body).to include(journal_path(locale: 'en'), work_path(locale: 'en'),
                                       contact_path(locale: 'en'))
    end

    # The hero is the studio speaking, and every number in it is counted rather than typed. The
    # headcount is people: the reviewer in CI is on the crew, and it is not one.
    it 'counts the projects, the people, the year the oldest project started and the entries' do
      get root_path(locale: 'en')

      humans = Team.crew.count { |person| !person.machine? }
      figures = response.parsed_body.css('.hm-figure').to_h do |figure|
        [figure.at_css('dt').text, figure.at_css('dd').text]
      end

      expect(humans).to be < Team.crew.size
      expect(figures).to eq('products in the portfolio' => Case.count.to_s, 'people on the team' => humans.to_s,
                            'the portfolio’s first project' => '2022', 'entry in the journal' => '1')
    end

    it 'carries the headline and both halves of the lede' do
      get root_path(locale: 'en')

      expect(response.body).to include(I18n.t('home.index.headline_lead', locale: :en))
      expect(response.body).to include(I18n.t('home.index.headline_mark', locale: :en))
      # The sentence a competitor's site will not print, and the reason the good numbers above
      # it are believable.
      expect(response.body).to include('outage that lasted eleven hours')
    end

    it 'shows the featured post when one is flagged, and the newest otherwise' do
      get root_path(locale: 'en')
      expect(response.body).to include('The newest entry')

      featured = I18n.with_locale(:en) { create(:post, :main_post, status: 'active', title: 'The featured one') }

      get root_path(locale: 'en')
      expect(response.body).to include('The featured one')
      expect(featured.reload).to be_main_post
    end

    it 'does not feature a post that has no text in the reader\'s language' do
      I18n.with_locale(:uk) { create(:post, :main_post, status: 'active', title: 'Тільки українською') }

      get root_path(locale: 'en')

      expect(response.body).to include('The newest entry')
      expect(response.body).not_to include('Тільки українською')
    end

    it 'falls back to the newest entry when the only featured post is hidden' do
      I18n.with_locale(:en) { create(:post, :main_post, :inactive, title: 'The hidden feature') }

      get root_path(locale: 'en')

      expect(response.body).to include('The newest entry')
      expect(response.body).not_to include('The hidden feature')
    end

    it 'draws the first three cases as panels and the rest of the portfolio as tiles' do
      get root_path(locale: 'en')

      expect(response.parsed_body.css('a.hm-case').size).to eq(HomeController::RECENT_CASES)
      expect(response.parsed_body.css('a.hm-mini').size).to eq(Case.count - HomeController::RECENT_CASES)
      expect(response.body).to include(work_case_path(slug: 'intelligence', locale: 'en'))
    end

    # The cards used to open on a pale box holding the case number, printed again under the
    # title: it read as a missing picture.
    it 'opens each card on its stone and its headline figure, not on a numbered box' do
      get root_path(locale: 'en')

      cards = response.parsed_body.css('.hm-case')
      intelligence = Case.find_by!(slug: 'intelligence')

      expect(cards.css('.hm-case__cover, .hm-case__glyph, .hm-case__mark')).to be_empty
      expect(cards.css('.hm-case__lead svg.rc-gem').size).to eq(HomeController::RECENT_CASES)
      expect(cards.first.at_css('.hm-case__figure[data-controller="count-up"]').text)
        .to eq(ProseHelper.plain(intelligence.headline_metric[:value]))
    end

    it 'gives each card a different shade of the stone' do
      get root_path(locale: 'en')

      shades = response.parsed_body.css('.hm-case').map { |card| card.at_css('stop')['stop-color'] }

      expect(shades.uniq.size).to eq(HomeController::RECENT_CASES)
    end

    # On a phone the gem floats beside the headline; it has to sit inside the copy for that.
    it 'puts the hero gem in a button, ahead of the headline' do
      get root_path(locale: 'en')

      copy = response.parsed_body.at_css('.hm-hero__copy')
      button = copy.at_css('.hm-hero__gem button.hm-hero__stone[type="button"][data-ruby-handle]')

      expect(button['aria-label']).to eq('The ruby — press for another shade')
      expect(copy.children.css('.hm-hero__gem, h1').map(&:name)).to eq(%w[div h1])
    end

    # Both live in the layout, so every public page has them.
    it 'offers the quote card as a PNG, and as an image to copy only once script finds a clipboard' do
      get root_path(locale: 'uk')

      quote = response.parsed_body.at_css('[data-controller="quote-card"]')

      expect(quote.at_css('button[data-action="quote-card#download"]').text.strip).to eq('завантажити PNG')
      expect(quote.at_css('button[data-quote-card-target="copy"]').key?('hidden')).to be(true)
      expect(quote['data-quote-card-saved-value']).to include('rubycoin-quote.png')
    end

    it 'carries the easter egg’s caption as a live region, with a still variant for reduced motion' do
      get root_path(locale: 'en')

      egg = response.parsed_body.at_css('[data-controller="gem-egg"]')

      expect(egg.at_css('[role="status"][data-gem-egg-target="toast"]')).to be_present
      expect(egg['data-gem-egg-message-value']).to include('easter egg')
      expect(egg['data-gem-egg-still-value']).to include('less motion')
    end

    # The third surface showing the roster, and it reads the same file as /studio and /team.
    it 'shows the crew, each row linking at that person' do
      get root_path(locale: 'en')

      expect(response.body.scan('class="hm-crew__row hover-row"').size).to eq(Team.crew.size)
      expect(response.body).to include(person_path('claude', locale: 'en'))
    end

    it 'counts the humans on the roster separately, because one of them is not' do
      get root_path(locale: 'en')

      humans = Team.crew.count { |person| !person.machine? }

      expect(response.body).to include("#{Team.crew.size} on the team — #{humans} of them human.")
    end

    # It used to be one five-column strip here, attributed to the studio as a whole. A studio
    # does not play volleyball on Tuesdays — one specific person does.
    it 'carries no not-work strip: that lives on a person page now' do
      get root_path(locale: 'en')

      expect(response.body).not_to include('tm-notwork')
    end

    it 'renders the Ukrainian copy under the uk locale' do
      get root_path(locale: 'uk')

      expect(response.body).to include(I18n.t('home.index.headline_lead', locale: :uk))
      expect(response.body).to include("У команді #{Team.crew.size}")
    end
  end

  # The old front page was the article stream; these query strings were its pagination and tag
  # filter. They are gone for good, so they move to /journal permanently.
  describe 'the stream URLs the old home page had' do
    # The old addresses carried no locale, and the old stream answered in Ukrainian.
    context 'when the address is the locale-less one a crawler holds' do
      it 'answers ?page= with one permanent hop to the journal' do
        get '/?page=1'

        expect(response).to have_http_status(:moved_permanently)
        expect(response).to redirect_to('/uk/journal?page=1')
      end

      it 'carries a tag filter and the ordering across' do
        get '/?tag_ids[]=7&order=best'

        expect(response).to have_http_status(:moved_permanently)
        expect(response).to redirect_to('/uk/journal?order=best&tag_id=7')
      end

      it 'answers ?order= in the same hop' do
        get '/?order=oldest'

        expect(response).to have_http_status(:moved_permanently)
        expect(response).to redirect_to('/uk/journal?order=oldest')
      end

      it 'does not let the browser pick the language of a permanent redirect' do
        get '/?order=oldest', headers: { 'Accept-Language' => 'en' }

        expect(response).to redirect_to('/uk/journal?order=oldest')
      end
    end

    context 'when the address names its locale' do
      it 'sends ?page= to the journal' do
        get root_path(locale: 'en', page: 1)

        expect(response).to have_http_status(:moved_permanently)
        expect(response).to redirect_to(journal_path(locale: 'en', page: '1'))
      end

      it 'carries a tag filter across' do
        get root_path(locale: 'en', tag_ids: ['7'])

        expect(response).to redirect_to(journal_path(locale: 'en', tag_id: '7'))
      end

      it 'carries the ordering across' do
        get root_path(locale: 'uk', order: 'best')

        expect(response).to redirect_to(journal_path(locale: 'uk', order: 'best'))
      end
    end

    # The stream held six entries a page and the journal holds JournalController::PER_PAGE, so
    # the same number would name different entries.
    it 'keeps the page pointing at the entries it used to show' do
      stub_const('JournalController::PER_PAGE', 20)

      get root_path(locale: 'en', page: 8)

      expect(response).to redirect_to(journal_path(locale: 'en', page: '3'))
    end

    it 'leaves the home page alone without them' do
      get root_path(locale: 'en')

      expect(response).to have_http_status(:success)
    end

    # Anyone can append ?page[]= to the most visited address; it is not a moved page.
    context 'when a value is not one the stream ever sent' do
      [
        'page[x]=1', 'page[]=1', 'order[x]=1', 'order=sideways', 'tag_ids[a]=b', 'tag_ids[0]=5&tag_ids[1]=6',
        'page=abc', 'page=-3', 'page=1.5', 'tag_ids[][x]=1', 'tag_ids[]=abc', 'tag_ids[]=1%00'
      ].each do |query|
        it "renders the home page for ?#{query}" do
          get "/en?#{query}"

          expect(response).to have_http_status(:success)
        end
      end

      it 'still moves what is usable when the rest is not' do
        get '/en?page[x]=1&order=best&tag_ids[a]=b'

        expect(response).to redirect_to(journal_path(locale: 'en', order: 'best'))
      end

      it 'forwards the first usable tag of several' do
        get '/en?tag_ids[]=&tag_ids[]=3&tag_ids[]=4'

        expect(response).to redirect_to(journal_path(locale: 'en', tag_id: '3'))
      end
    end
  end
end
