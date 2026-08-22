# frozen_string_literal: true

require 'rails_helper'

describe FaqController do
  render_views

  describe 'GET #index' do
    let(:action) { :index }
    let(:params) { {} }

    it_behaves_like 'has http success'

    it 'renders every question the copy holds, on the theme layout' do
      get(action, params: { locale: 'en' })

      expect(response.body.scan('class="fq-entry"').size).to eq(I18n.t('faq', locale: :en).size)
      expect(response.body).to include('rc-footer')
    end

    it 'renders a link inside an answer as a link' do
      get(action, params: { locale: 'en' })

      expect(response.body).to include('Meet the author of the channel</a>')
    end

    it 'reads the Ukrainian copy under the uk locale' do
      get(action, params: { locale: 'uk' })

      expect(response.body).to include(I18n.t('faq.who_am_i.question1', locale: :uk))
    end

    # Restyled but deliberately not promoted: the nav still carries its four sections, and
    # /en/faq appears on the page only because the locale switcher points at the page itself.
    it 'is not one of the nav sections' do
      get(action, params: { locale: 'en' })

      nav = response.body[%r{rc-nav__sections.*?</div>}m]
      expect(nav.scan('rc-nav__link').size).to eq(4)
      expect(nav).not_to include('faq')
    end
  end
end
