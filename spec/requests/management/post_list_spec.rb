# frozen_string_literal: true

require 'rails_helper'

# Filter rail, search, server-side sorting and the language-pair indicator.
describe 'the admin post list', type: :request do
  include_context 'when carrierwave cleanup'

  let!(:published) { bilingual(entry_number: 11, updated_at: 2.days.ago) }
  let!(:hidden) { bilingual(:inactive, entry_number: 12, updated_at: 1.day.ago) }

  before { sign_in create(:user, role: :admin) }

  # Real posts carry both languages; the factory only fills the locale it runs in.
  def bilingual(*traits, **attributes)
    post = I18n.with_locale(:en) { create(:post, *traits, **attributes) }
    I18n.with_locale(:uk) { post.update!(title: 'Заголовок', subtitle: 'Лід') }
    post
  end

  def list(**) = get(management_posts_path(locale: 'en', **))

  it 'shows every post and counts the two states it has' do
    list

    expect(response.body.scan('class="mg-title"').size).to eq(2)
    expect(response.body).to include('mg-status--active', 'mg-status--inactive')
  end

  it 'filters by status' do
    list(status: 'inactive')

    expect(response.body.scan('class="mg-title"').size).to eq(1)
    expect(response.body).to include(hidden.slug)
    expect(response.body).not_to include(published.slug)
  end

  it 'ignores a status that is not one of the two' do
    list(status: 'archived')

    expect(response.body.scan('class="mg-title"').size).to eq(2)
  end

  it 'searches titles and bodies' do
    I18n.with_locale(:en) { published.update!(title: 'A findable heading', subtitle: 'lede') }

    list(query: 'findable')

    expect(response.body).to include(published.slug)
    expect(response.body).not_to include(hidden.slug)
  end

  it 'says so when a search finds nothing' do
    list(query: 'nothing-matches-this')

    expect(response.body).to include('mg-empty')
  end

  # A column name from the query string must never reach ORDER BY.
  it 'sorts only by the columns it allows' do
    list(sort: 'number', direction: 'asc')

    expect(response.body.index(published.slug)).to be < response.body.index(hidden.slug)

    list(sort: 'number', direction: 'desc')

    expect(response.body.index(hidden.slug)).to be < response.body.index(published.slug)
  end

  it 'falls back to the default sort when asked for a column it does not allow' do
    list(sort: 'id); drop table posts;--')

    expect(response).to have_http_status(:success)
    # Default is updated_at desc, so the more recently touched row comes first.
    expect(response.body.index(hidden.slug)).to be < response.body.index(published.slug)
  end

  it 'shows which languages each post is finished in' do
    published.translations.find_by(locale: 'en').update!(subtitle: nil)

    list

    expect(response.body.scan('mg-lang is-present').size).to eq(3)
  end
end
