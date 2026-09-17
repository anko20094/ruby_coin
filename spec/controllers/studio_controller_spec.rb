# frozen_string_literal: true

require 'rails_helper'

describe StudioController do
  render_views

  let(:action) { :show }
  let(:params) { { locale: 'en' } }

  it_behaves_like 'has http success'

  it 'shows the whole roster, each card linking at that person' do
    get(action, params:)

    expect(response.body.scan('class="st-card"').size).to eq(Team.crew.size)
    expect(response.body).to include(person_path('mykhailo', locale: 'en'))
  end

  # This page sat English-only above correctly translated crew cards for a while, which reads
  # worse than no translation at all.
  it 'translates its own copy, not only the roster' do
    get(action, params: { locale: 'uk' })

    expect(response.body).to include('Студія', 'Rails-студія')
    expect(response.body).not_to include('The studio')
  end

  describe 'the alumni' do
    let(:alumni_block) { response.body[%r{<section class="st-alumni".*?</section>}m] }

    it 'names every one of them' do
      get(action, params:)

      # #name reads I18n.locale when it is called, not when the record was loaded, so the names
      # have to be rendered inside the block or they come out in the suite's default locale.
      names = I18n.with_locale(:en) { Team.alumni.map(&:name) }

      names.each { |name| expect(alumni_block).to include(name) }
      expect(alumni_block.scan('st-alumni__pill').size).to eq(Team.alumni.size)
    end

    # The distinction the page is built on. A name with nothing behind it must not be a link:
    # the page it would open cannot exist without inventing a career for someone who is not here
    # to correct it. A name still credited on a project has the opposite problem — the case page
    # already links at them, so this one has to as well.
    it 'links the ones with something behind the name, and only those' do
      get(action, params:)

      linked = Team.alumni.select(&:page?)

      expect(linked).to be_present, 'no alumnus is credited, so this rule proves nothing'
      expect(alumni_block.scan('<a ').size).to eq(linked.size)
      linked.each { |person| expect(alumni_block).to include(person_path(person, locale: 'en')) }
    end

    it 'translates their names rather than leaving the roster half in Latin' do
      get(action, params: { locale: 'uk' })

      expect(response.body).to include('Андрій Мазурок')
      expect(response.body).not_to include('Andrii Mazurok')
    end
  end
end
