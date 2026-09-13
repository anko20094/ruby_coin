# frozen_string_literal: true

require 'rails_helper'

# ⌘K (handoff §9a). The handoff is explicit that it should be backed by the existing /search
# PgSearch action rather than filtering in memory — the prototype only did that for want of a
# server.
describe 'the command palette', type: :request do
  include_context 'when carrierwave cleanup'
  include_context 'when the cases are imported'
  include_context 'when the cv is imported'

  let!(:post_record) do
    I18n.with_locale(:en) { create(:post, status: 'active', title: 'Counting views properly') }
  end

  def palette(query, locale: 'en')
    get search_path(locale: locale, query: query, format: :json)
    response.parsed_body['results']
  end

  it 'finds journal entries' do
    expect(palette('counting').pluck('title')).to include('Counting views properly')
  end

  it 'finds cases, which the journal search alone cannot' do
    expect(palette('dna').pluck('kind')).to include('case')
  end

  it 'finds people, whom neither the journal search nor the cases can' do
    result = palette('natalia').find { |r| r['kind'] == 'person' }

    expect(result['url']).to eq(person_path('natalia', locale: 'en'))
  end

  # The names are translated and the ids are not, so the id is matched too.
  it 'finds a person by id on a Ukrainian page' do
    expect(palette('natalia', locale: 'uk').pluck('kind')).to include('person')
  end

  # The CV page is called "Curriculum vitae" and nobody types that. The address is the other
  # name every page has, and it is the one on the nav chip.
  it 'finds a page by its address when the title shares no word with it' do
    result = palette('cv').find { |r| r['kind'] == 'page' }

    expect(result['url']).to eq(cv_path(locale: 'en'))
  end

  it 'finds the roster by its address on a Ukrainian page' do
    expect(palette('team', locale: 'uk').pluck('url')).to include(team_path(locale: 'uk'))
  end

  # A page is often called two things: the roster's heading is "Who is here" and every other
  # surface — the footer, the eyebrow — calls it команда.
  it 'finds a page by the other name the site prints for it' do
    expect(palette('команда', locale: 'uk').pluck('url')).to include(team_path(locale: 'uk'))
    expect(palette('crew').pluck('url')).to include(team_path(locale: 'en'))
  end

  it 'finds the pages themselves' do
    result = palette('contact').find { |r| r['kind'] == 'page' }

    expect(result['url']).to eq(contact_path(locale: 'en'))
  end

  # The browser prints a row with textContent, so an entity arrives as its own characters.
  it 'answers with text rather than with entities' do
    expect(palette('mykhailo').first['hint']).to eq('cofounder · product & clients')
  end

  # The badge beside each row is read, so it is translated; `kind` stays the machine word.
  it 'labels each row in the reader\'s language' do
    expect(palette('dna').first['kind']).to eq('case')
    expect(palette('dna').first['label']).to eq('case')
    expect(palette('dna', locale: 'uk').first['label']).to eq('кейс')
  end

  it 'never offers a hidden entry' do
    I18n.with_locale(:en) { create(:post, status: 'inactive', title: 'Counting secrets') }

    expect(palette('counting').pluck('title')).not_to include('Counting secrets')
  end

  it 'answers nothing for an empty query rather than the whole site' do
    expect(palette('')).to eq([])
  end

  it 'caps the list at what the design draws' do
    create_list(:post, Search::Palette::LIMIT + 2, status: 'active')

    expect(palette('e').size).to be <= Search::Palette::LIMIT
  end

  it 'links into the language it was asked in' do
    expect(palette('dna', locale: 'uk').first['url']).to start_with('/uk/')
  end

  it 'is reachable from every page, and says which keys open it' do
    get '/en/journal'

    expect(response.body).to include('data-controller="palette"')
    expect(response.body).to include('rc-palette__legend')
  end
end
