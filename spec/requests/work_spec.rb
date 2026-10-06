# frozen_string_literal: true

require 'rails_helper'

describe 'the work pages', type: :request do
  include_context 'when the cases are imported'

  describe 'GET /work' do
    it 'renders one card per project, all the same size' do
      get work_path(locale: 'uk')

      expect(response).to have_http_status(:ok)
      expect(response.body.scan('class="wk-project hover-row"').size).to eq(7)
    end

    it 'lets J/K walk the cards, with a hint drawn hidden until the script is there' do
      get work_path(locale: 'en')

      deck = response.parsed_body.at_css('.wk-index[data-controller~="list-nav"]')
      expect(deck['data-list-nav-item-value']).to eq('.wk-project')
      expect(deck.at_css('p.rc-keys[hidden]').text.squish).to eq('J K — navigate · / — search')
    end

    # Hand-ordered and numbered reads as a rank; the mark stays on the case page and /cv.
    it 'prints no case mark on the cards' do
      get work_path(locale: 'uk')

      expect(response.body).not_to include('wk-project__mark')
    end

    it 'shows who built each project, or says solo' do
      get work_path(locale: 'en')

      expect(response.body).to include('rc-monogram')
      # myHomeIQ Intelligence and Leads: the wider team there was the client's.
      expect(response.body.scan('>solo<').size).to eq(2)
      # Not "6 people": one of the six credited on DNA is the machine.
      expect(response.body).to include('6 contributors')
    end

    # Cases and team.yml can be out of step in production; nobody credited prints nothing, not "0".
    it 'says nothing about a team where nobody is credited yet' do
      Case.create!(slug: 'brand-new', mark: '08', position: 8,
                   year: '2026', sector: { 'en' => 'new', 'uk' => 'нове' },
                   status: { 'en' => 'x', 'uk' => 'х' },
                   title: { 'en' => 'Brand new', 'uk' => 'Новий' },
                   tagline: { 'en' => 'x', 'uk' => 'х' }, role: { 'en' => 'x', 'uk' => 'х' },
                   plain_heading: { 'en' => 'x', 'uk' => 'х' },
                   engineering_heading: { 'en' => 'x', 'uk' => 'х' },
                   engineering_sub: { 'en' => 'x', 'uk' => 'х' },
                   scope_note: { 'en' => 'x', 'uk' => 'х' })

      get work_path(locale: 'en')

      expect(response.body).to include('Brand new')
      expect(response.body).not_to include('0 contributors')
    end

    # The nav still offers the CV, so this checks the page's own blocks, not the word.
    it 'is projects only' do
      get work_path(locale: 'en')

      expect(response.body).not_to include('pf-career')
      expect(response.body).not_to include('pf-contact')
      expect(response.body).not_to include('cv-rows')
    end

    it 'renders the Ukrainian copy under the uk locale' do
      get work_path(locale: 'uk')

      expect(response.body).to include('Проєкти', 'ВЛАСНИЙ')
    end

    # Collapsing is the controller's job: without script every card is open and no toggle shows.
    describe 'the collapsible cards' do
      let(:cards) { response.parsed_body.css('article.wk-project') }

      before { get work_path(locale: 'en') }

      it 'draws every card open, with its toggle and the bar hidden until script takes over' do
        expect(cards.size).to eq(7)
        expect(cards.css('.wk-project.is-collapsed')).to be_empty
        expect(cards.css('.wk-project__toggle')).to all(satisfy { |toggle| toggle.key?('hidden') })
        expect(response.parsed_body.at_css('.wk-deck__bar').key?('hidden')).to be(true)
      end

      it 'points each toggle at the part it folds, and says open' do
        cards.each do |card|
          toggle = card.at_css('button.wk-project__toggle[type="button"]')
          details = card.at_css(".wk-project__details##{toggle['aria-controls']}")

          expect(details).to be_present
          expect(toggle['aria-expanded']).to eq('true')
          expect(toggle['aria-label']).to start_with('Description and stack: ')
        end
      end

      it 'folds the description and the stack, and keeps the title, figure and team outside' do
        card = cards.first

        expect(card.at_css('.wk-project__details .wk-project__tagline')).to be_present
        expect(card.at_css('.wk-project__details .wk-project__stack')).to be_present
        expect(card.at_css('.wk-project__details .wk-project__metric')).to be_nil
        expect(card.at_css('.wk-project__foot .wk-project__metric-value[data-controller="count-up"]')).to be_present
      end

      it 'keeps the title as the link to the case' do
        link = cards.first.at_css('h2.wk-project__title a.wk-project__link')

        expect(link['href']).to eq(work_case_path(slug: 'intelligence', locale: 'en'))
      end

      it 'lets a floating card fold on a click outside or Esc' do
        actions = response.parsed_body.at_css('.wk-deck[data-controller="card-collapse"]')['data-action'].split

        expect(actions).to include('click@document->card-collapse#clickOutside',
                                   'keydown.esc@document->card-collapse#escape')
      end

      it 'keeps the flags on the sector line, and the years in one piece' do
        card = cards.find { |c| c.at_css('.wk-project__own') }

        expect(card.at_css('.wk-project__meta > .wk-project__flags .wk-project__own')).to be_present
        expect(card.at_css('.wk-project__meta > .wk-project__sector .wk-project__year')).to be_present
      end

      it 'labels the expand-all control in both directions' do
        all = response.parsed_body.at_css('.wk-deck__all')

        expect(all['data-expand-label']).to eq('expand all')
        expect(all['data-collapse-label']).to eq('collapse all')
      end
    end
  end

  describe 'the view transition from a card to its case' do
    # The list only carries the name; view_transitions.js puts it on the card being opened.
    it 'gives the card title and the case heading the same name, one per case' do
      get work_path(locale: 'en')
      titles = response.parsed_body.css('h2.wk-project__title')
      names = titles.pluck('data-vt-name')
      expect(names).to include('case-title-dna')
      expect(names.uniq.size).to eq(names.size)
      expect(titles.pluck('style').compact).to be_empty

      get work_case_path(locale: 'en', slug: 'dna')
      expect(response.parsed_body.at_css('h1.wk-case__title')['style']).to eq('view-transition-name: case-title-dna')
    end
  end

  describe 'the journal and the cases, linked by tags' do
    include_context 'when carrierwave cleanup'

    let!(:entry) do
      I18n.with_locale(:en) do
        create(:post, status: 'active', title: 'Hotwire, honestly',
                      tags: [create(:tag, title: 'hotwire'), create(:tag, title: 'rails')])
      end
    end

    it 'lists the entries on a case whose stack their tags name' do
      get work_case_path(locale: 'en', slug: 'rubycoin')

      block = response.parsed_body.at_css('section.wk-case__journal')
      expect(block.text).to include('entries on this topic')
      expect(block.css('a.wk-entry').pluck('href')).to eq([post_path(entry, locale: 'en')])
    end

    it 'marks the tags that made the match, and leads on to the journal by the strongest' do
      get work_case_path(locale: 'en', slug: 'rubycoin')

      block = response.parsed_body.at_css('section.wk-case__journal')
      expect(block.css('.wk-entry__tag.is-shared').map(&:text)).to eq(['#hotwire'])
      expect(block.css('.wk-entry__tag:not(.is-shared)').map(&:text)).to eq(['#rails'])

      all = block.at_css('a.wk-entries__all')
      expect(all.text).to include('every entry tagged #hotwire')
      expect(all['href']).to eq(journal_path(locale: 'en', tag_id: Tag.find_by(title: 'hotwire').id))
    end

    it 'draws no block on a case nothing in the journal is about' do
      get work_case_path(locale: 'en', slug: 'imagemaker')

      expect(response.parsed_body.at_css('.wk-case__journal')).to be_nil
    end

    it 'points the entry at its project' do
      get post_path(entry, locale: 'en')

      link = response.parsed_body.at_css('.jn-post__project a')
      expect(response.parsed_body.at_css('.jn-post__project').text).to start_with('project ·')
      expect(link['href']).to eq(work_case_path(locale: 'en', slug: 'rubycoin'))
    end

    it 'gives an entry tagged only with what every project has no project link' do
      entry.tags = [Tag.find_by(title: 'rails')]

      get post_path(entry, locale: 'en')

      expect(response.parsed_body.at_css('.jn-post__project')).to be_nil
    end
  end

  describe 'the rail beside a case' do
    let(:rail) do
      get work_case_path(locale: 'en', slug: 'dna')
      response.parsed_body.at_css('aside.wk-rail[data-controller="case-rail"]')
    end

    it 'lists the sections, each an anchor the page has' do
      links = rail.css('a.wk-rail__link')

      expect(links.map(&:text)).to eq(['in plain words', 'for engineers', 'who worked on it', 'talk it through'])
      links.each { |link| expect(response.parsed_body.at_css(link['href'])).to be_present }
    end

    it 'carries a static copy of the figures, hidden until the strip is out of sight' do
      metrics = rail.at_css('dl.wk-rail__metrics[hidden][aria-hidden="true"]')

      expect(metrics.css('dd.wk-rail__value').size).to eq(Case.find_by!(slug: 'dna').metrics.size)
      expect(metrics.css('[data-controller~="count-up"]')).to be_empty
    end
  end

  describe 'GET /work/:slug' do
    it 'counts up every figure in both metric strips, from the text the server prints' do
      get work_case_path(slug: 'intelligence', locale: 'en')

      figures = response.parsed_body.css('.wk-metric__value, .wk-quality__value')

      expect(figures).to be_present
      expect(figures.pluck('data-controller')).to all(eq('count-up'))
      expect(figures.map(&:text)).to all(match(/\d/))
    end

    it 'renders both tracks' do
      get work_case_path(slug: 'intelligence', locale: 'en')

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('in plain words', 'for engineers')
    end

    it 'renders the scope note' do
      get work_case_path(slug: 'intelligence', locale: 'en')

      expect(response.body).to include('Scope, honestly')
    end

    it 'renders inline markup from the content as markup' do
      get work_case_path(slug: 'intelligence', locale: 'uk')

      expect(response.body).to include('<code>pg_trgm</code>')
    end

    it 'drops a step in title size for long titles' do
      get work_case_path(slug: 'intelligence', locale: 'uk')

      expect(response.body).to include('wk-case__title is-long')
    end

    it 'keeps the full title size for short ones' do
      get work_case_path(slug: 'dna', locale: 'uk')

      expect(response.body).not_to include('is-long')
    end

    it 'ends with the people who built it, each linking at their page with the project in tow' do
      get work_case_path(slug: 'dna', locale: 'en')

      expect(response.body).to include('wk-case__team')
      expect(response.body.scan('class="wk-teammate hover-row"').size).to eq(6)
      expect(response.body).to include("#{person_path('danyil', locale: 'en')}?from=dna")
      expect(response.body.index('wk-case__team')).to be > response.body.index('id="engineers"')
    end

    # A grid holding one lonely card reads as an unfinished page; this reads as a claim.
    it 'states solo work instead of drawing a team of one' do
      get work_case_path(slug: 'intelligence', locale: 'en')

      expect(response.body).to include('Solo — the whole stack')
      expect(response.body).not_to include('wk-teammate')
    end

    it 'names whose team the other contributors were on solo commercial work' do
      get work_case_path(slug: 'leads', locale: 'en')

      expect(response.body).to include('wk-solo__outside')
      expect(response.body).to include('34 contributors')
    end

    it 'wraps the pager at the end of the list' do
      get work_case_path(slug: 'rubycoin', locale: 'uk')

      expect(response.body).to include(work_case_path(slug: 'intelligence', locale: 'uk'))
    end
  end

  # Which cases recruiters open is the number meant to decide the order of /work.
  describe 'view tracking' do
    include_context 'when carrierwave cleanup'

    it 'records one view per case' do
      expect { get work_case_path(slug: 'dna', locale: 'en'), headers: browser_headers }
        .to change { Ahoy::Event.where(name: 'Viewed Case').count }.by(1)
    end

    it 'stores the case id, so a renamed case keeps its history' do
      get work_case_path(slug: 'dna', locale: 'en'), headers: browser_headers

      event = Ahoy::Event.where(name: 'Viewed Case').last
      expect(event.properties['case_id']).to eq(Case.find_by!(slug: 'dna').id)
      expect(event.properties['slug']).to eq('dna')
    end

    it 'does not count the same reader twice inside the window' do
      get work_case_path(slug: 'dna', locale: 'en'), headers: browser_headers

      expect { get work_case_path(slug: 'dna', locale: 'en'), headers: browser_headers }
        .not_to(change { Ahoy::Event.where(name: 'Viewed Case').count })
    end

    it 'counts a different case in the same session' do
      get work_case_path(slug: 'dna', locale: 'en'), headers: browser_headers

      expect { get work_case_path(slug: 'leads', locale: 'en'), headers: browser_headers }
        .to change { Ahoy::Event.where(name: 'Viewed Case').count }.by(1)
    end
  end
end
