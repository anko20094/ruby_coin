# frozen_string_literal: true

require 'rails_helper'

describe 'Management CV screens', type: :request do
  include_context 'when the cv is imported'

  let(:admin) { create(:user, role: :admin) }

  context 'when an admin is signed in' do
    before { sign_in(admin) }

    describe 'the CV frame' do
      it 'renders a field per language and the contact rows' do
        get edit_management_cv_profile_path(locale: 'en')

        expect(response).to be_successful
        expect(response.body).to include('cv_profile[name_en]', 'cv_profile[name_uk]')
        expect(response.body).to include('cv_profile[contact_rows][0][key]')
        # Four rows plus a spare to add one.
        expect(response.body.scan(/cv_profile\[contact_rows\]\[\d+\]\[key\]/).size).to eq(5)
      end

      it 'updates the frame' do
        patch management_cv_profile_path(locale: 'en'),
              params: { cv_profile: { summary_en: 'Rewritten', summary_uk: 'Переписано' } }

        expect(CVProfile.current[:summary]).to eq({ 'en' => 'Rewritten', 'uk' => 'Переписано' })
      end

      it 'refuses a frame written in one language only' do
        patch management_cv_profile_path(locale: 'en'), params: { cv_profile: { summary_en: 'x', summary_uk: '' } }

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    describe 'the CV blocks' do
      it 'lists them grouped by kind' do
        get management_cv_blocks_path(locale: 'en')

        expect(response).to be_successful
        expect(response.body.scan('class="cv-kind"').size).to eq(CVBlock::KINDS.size)
        expect(response.body.scan('class="case-row"').size).to eq(10)
      end

      it 'draws only the fields the kind has' do
        get new_management_cv_block_path(locale: 'en', kind: 'stack_group')

        expect(response.body).to include('cv_block[label_en]', 'cv_block[items_list]')
        expect(response.body).not_to include('cv_block[org_en]')
      end

      it 'creates a strength' do
        params = { cv_block: { kind: 'strength', position: 9, text_en: 'Ships things', text_uk: 'Довозить' } }

        expect { post management_cv_blocks_path(locale: 'en'), params: params }
          .to change(CVBlock, :count).by(1)

        expect(CVBlock.strengths.last.payload).to eq({ 'text' => { 'en' => 'Ships things', 'uk' => 'Довозить' } })
      end

      it 'refuses a block whose kind has no payload' do
        expect { post management_cv_blocks_path(locale: 'en'), params: { cv_block: { kind: 'strength', position: 9 } } }
          .not_to change(CVBlock, :count)
      end

      it 'deletes a block' do
        expect { delete management_cv_block_path(CVBlock.strengths.first, locale: 'en') }
          .to change(CVBlock, :count).by(-1)
      end
    end
  end

  context 'when a moderator is signed in' do
    before { sign_in(create(:user, role: :moderator)) }

    it 'may look but not write' do
      get management_cv_blocks_path(locale: 'en')
      expect(response).to be_successful

      params = { cv_block: { kind: 'strength', position: 9, text_en: 'x', text_uk: 'ікс' } }

      expect { post management_cv_blocks_path(locale: 'en'), params: params }.not_to change(CVBlock, :count)
    end
  end

  context 'when nobody is signed in' do
    it 'sends them to sign in' do
      get management_cv_blocks_path(locale: 'en')

      expect(response).to redirect_to(new_user_session_path(locale: I18n.default_locale))
    end
  end
end
