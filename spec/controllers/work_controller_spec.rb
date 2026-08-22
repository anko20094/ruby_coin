# frozen_string_literal: true

require 'rails_helper'

describe WorkController do
  render_views

  include_context 'when the cases are imported'

  describe 'GET #index' do
    let(:action) { :index }
    let(:params) { {} }

    it_behaves_like 'has http success'

    it 'renders the seven project rows as links' do
      get(action, params:)

      expect(response.body.scan('class="wk-row hover-row"').size).to eq(7)
    end

    it 'renders the CV frame' do
      get(action, params:)

      expect(response.body).to include('Danyil Shkoropad', 'myHomeIQ', 'pgvector')
    end

    it 'renders the portrait when one is in place' do
      allow(Portfolio).to receive(:portrait).and_return('work-portrait.jpg')

      get(action, params:)

      expect(response.body).to include('wk-portrait')
    end

    it 'leaves the portrait block out when there is none' do
      allow(Portfolio).to receive(:portrait).and_return(nil)

      get(action, params:)

      expect(response.body).not_to include('wk-portrait')
    end

    it 'renders the Ukrainian copy under the uk locale' do
      get(action, params: { locale: 'uk' })

      expect(response.body).to include('Що я зробив', 'проєкти')
    end
  end

  describe 'GET #show' do
    let(:action) { :show }
    let(:params) { { slug: 'intelligence' } }

    it_behaves_like 'has http success'

    it 'renders both tracks' do
      get(action, params: params.merge(locale: 'en'))

      expect(response.body).to include('in plain words', 'for engineers')
    end

    it 'renders the scope note' do
      get(action, params: params.merge(locale: 'en'))

      expect(response.body).to include('Scope, honestly')
    end

    it 'renders inline markup from the content as markup' do
      get(action, params:)

      expect(response.body).to include('<code>pg_trgm</code>')
    end

    it 'drops a step in title size for long titles' do
      get(action, params:)

      expect(response.body).to include('wk-case__title is-long')
    end

    it 'keeps the full title size for short ones' do
      get(action, params: { slug: 'dna' })

      expect(response.body).not_to include('is-long')
    end

    it 'wraps the pager at the end of the list' do
      get(action, params: { slug: 'rubycoin' })

      expect(response.body).to include(work_case_path(slug: 'intelligence'))
    end

    it 'raises for an unknown slug' do
      expect { get(action, params: { slug: 'nope' }) }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
