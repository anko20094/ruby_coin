# frozen_string_literal: true

require 'rails_helper'

describe 'the FAQ', type: :request do
  it 'renders every question the copy holds, on the theme layout' do
    get faq_path(locale: 'en')

    expect(response).to have_http_status(:ok)
    expect(response.body.scan('class="fq-entry"').size).to eq(I18n.t('faq', locale: :en).size)
    expect(response.body).to include('rc-footer')
  end

  it 'renders a link inside an answer as a link, in the page’s locale' do
    get faq_path(locale: 'en')

    expect(response.body).to include('<a href="/en/contact">Contact</a>')
  end

  # The old copy described a volunteer learning hub; the studio sells Rails work.
  it 'speaks for a commercial studio, with no mentoring or Discord left over' do
    %w[en uk].each do |locale|
      get faq_path(locale: locale)

      text = response.body.downcase
      expect(text).not_to include('discord')
      expect(text).not_to include(locale == 'en' ? 'mentoring' : 'менторств')
    end
  end

  it 'reads the Ukrainian copy under the uk locale' do
    get faq_path(locale: 'uk')

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(I18n.t('faq.who_am_i.question1', locale: :uk))
  end

  # Not promoted: /en/faq is on the page only because the locale switcher points at itself.
  it 'is not one of the nav sections' do
    get faq_path(locale: 'en')

    nav = response.body[%r{rc-nav__sections.*?</div>}m]
    expect(nav.scan('rc-nav__link').size).to eq(3)
    expect(nav).not_to include('faq')
  end
end
