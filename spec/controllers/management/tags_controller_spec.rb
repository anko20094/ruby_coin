# frozen_string_literal: true

require 'rails_helper'

describe Management::TagsController do
  describe 'GET #index' do
    let(:action) { :index }
    let(:params) { { locale: 'uk' } }

    context 'when admin is signed in' do
      before do
        admin_user = create(:user, role: :admin)
        sign_in(admin_user)
      end

      it_behaves_like 'has http success'
    end

    context 'when admin is not signed in' do
      it_behaves_like 'redirects to new_user_session_path'
    end
  end

  describe 'GET #new' do
    let(:action) { :new }
    let(:params) { { locale: 'uk' } }

    context 'when admin is signed in' do
      before do
        admin_user = create(:user, role: :admin)
        sign_in(admin_user)
      end

      it_behaves_like 'has http success'
    end

    context 'when admin is not signed in' do
      it_behaves_like 'redirects to new_user_session_path'
    end
  end

  describe 'GET #edit' do
    let(:tag) { create(:tag) }
    let(:action) { :edit }
    let(:params) { { locale: 'uk', id: tag.id } }

    context 'when admin is signed in' do
      before do
        admin_user = create(:user, role: :admin)
        sign_in(admin_user)
      end

      it_behaves_like 'has http success'
    end

    context 'when admin is not signed in' do
      it_behaves_like 'redirects to new_user_session_path'
    end
  end

  describe 'POST #create' do
    let(:valid_attributes) { attributes_for(:tag) }
    let(:invalid_attributes) { attributes_for(:tag, title: nil) }
    let(:action) { :create }
    let(:params) { { locale: 'uk', tag: valid_attributes } }

    context 'with valid parameters' do
      before do
        admin_user = create(:user, role: :admin)
        sign_in(admin_user)
      end

      it 'creates a new tag' do
        expect { post :create, params: { tag: valid_attributes } }.to change(Tag, :count).by(1)
      end

      it 'redirects to the new post' do
        post :create, params: { tag: valid_attributes }
        expected_path = response.location
        expect(response).to redirect_to(expected_path)
      end
    end

    context 'with invalid parameters' do
      let(:params) { { locale: 'uk', tag: invalid_attributes } }

      before { sign_in(create(:user, role: :admin)) }

      it_behaves_like 'unprocessable_entity status', :post

      it 'does not create a new tag' do
        expect { post(action, params:) }.not_to change(Tag, :count)
      end
    end

    context 'when user is not authenticated' do
      it_behaves_like 'redirects to new_user_session_path', :post
    end
  end

  describe 'PATCH #update' do
    let(:tag) { create(:tag) }
    let(:new_title) { 'Updated Title' }
    let(:action) { :update }
    let(:params) { { locale: 'uk', id: tag.id, tag: { title: new_title } } }

    context 'with valid parameters' do
      before do
        admin_user = create(:user, role: :admin)
        sign_in(admin_user)
      end

      it 'updates the tag' do
        patch(action, params:)
        tag.reload
        expect(tag.title).to eq(new_title)
      end
    end

    context 'with invalid parameters' do
      let(:params) { { locale: 'uk', id: tag.id, tag: { title: '' } } }

      before { sign_in(create(:user, role: :admin)) }

      it_behaves_like 'unprocessable_entity status', :patch

      it 'does not update the tag when title is blank' do
        expect { patch(action, params:) }.not_to(change { tag.reload.title })
      end
    end

    context 'when user is not authenticated' do
      it_behaves_like 'redirects to new_user_session_path', :patch
    end
  end

  describe 'DELETE #destroy' do
    let(:tag) { create(:tag) }
    let(:action) { :destroy }
    let(:params) { { locale: 'uk', id: tag.id } }

    context 'when admin is signed in' do
      before do
        admin_user = create(:user, role: :admin)
        sign_in(admin_user)
      end

      it 'responds with a redirect' do
        delete :destroy, params: { id: tag.id }
        expect(response).to have_http_status(:see_other)
      end
    end

    context 'when user is not authenticated' do
      it_behaves_like 'redirects to new_user_session_path', :delete
    end
  end
end
