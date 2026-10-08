# frozen_string_literal: true

require 'rails_helper'

describe 'the contact page', type: :request do
  it 'lists every channel from the CV as a real link' do
    get contact_path(locale: 'en')

    expect(response).to be_successful
    expect(response.body.scan('class="ct-channel"').size).to eq(Team.owner_cv.contact_rows.size)
    expect(response.body).to include('mailto:anko20094@gmail.com', 'https://t.me/anko20094')
  end

  # The prototype's contact page was full of invented addresses; none of them may ship.
  it 'carries no placeholder identity' do
    get contact_path(locale: 'en')

    expect(response.body).not_to include('hello@rubyco.in', 'press@rubyco.in', 'ronico-ua')
  end

  it 'has no form, by decision' do
    get contact_path(locale: 'en')

    expect(response.body).not_to include('<form')
  end

  it 'localises the heading and the lede' do
    get contact_path(locale: 'uk')

    expect(response.body).to include(I18n.t('contact.show.title', locale: :uk))
    expect(response.body).to include(I18n.t('contact.show.lede', locale: :uk))
  end
end
