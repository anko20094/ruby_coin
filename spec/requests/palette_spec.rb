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

  it 'finds the pages themselves' do
    result = palette('contact').find { |r| r['kind'] == 'page' }

    expect(result['url']).to eq(contact_path(locale: 'en'))
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
