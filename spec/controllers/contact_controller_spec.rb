# frozen_string_literal: true

require 'rails_helper'

describe ContactController, type: :request do
  include_context 'when the cv is imported'

  it 'lists every channel from the CV as a real link' do
    get contact_path(locale: 'en')

    expect(response).to be_successful
    expect(response.body.scan('class="ct-channel"').size).to eq(CVProfile.current.contact_rows.size)
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

  it 'renders nothing but the frame when the CV has not been imported' do
    CVProfile.delete_all

    get contact_path(locale: 'en')

    expect(response).to be_successful
    expect(response.body).not_to include('class="ct-channel"')
  end
end
