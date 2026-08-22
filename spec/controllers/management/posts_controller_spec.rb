# frozen_string_literal: true

require 'rails_helper'

describe Management::PostsController do
  describe 'GET #index' do
    let(:action) { :index }
    let(:params) { {} }

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

  describe 'GET #show' do
    let(:test_post) { create(:post) }
    let(:action) { :show }
    let(:params) { { id: test_post.id } }

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
    let(:params) { {} }

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
    let(:test_post) { create(:post) }
    let(:action) { :edit }
    let(:params) { { id: test_post.id } }

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

  describe 'PUT #update' do
    let(:test_post) { create(:post) }
    let(:action) { :update }
    let(:new_title) { 'Updated Title' }
    let(:params) { { id: test_post.slug, post: { title: new_title } } }
    let(:second_post) { create(:post, main_post: false) }
    let(:params_status_true_second_post) { { id: second_post.id, post: { main_post: 'true' } } }
    let(:params_status_false_second_post) { { id: second_post.id, post: { main_post: 'false' } } }
    let(:third_post) { create(:post, main_post: true) }
    let(:params_status_true_third_post) { { id: third_post.id, post: { main_post: 'true' } } }
    let(:params_status_false_third_post) { { id: third_post.id, post: { main_post: 'false' } } }

    context 'when admin is signed in' do
      before do
        admin_user = create(:user, role: :admin)
        sign_in(admin_user)
      end

      context 'with valid attributes' do
        it 'updates the post' do
          get(action, params:)
          test_post.reload
          expect(test_post.title).to eq(new_title)
        end

        context 'when main-post is false' do
          it 'changes from false to true' do
            get(action, params: params_status_true_second_post)
            second_post.reload
            expect(second_post.main_post).to be(true)
          end

          it 'doesnt change' do
            get(action, params: params_status_false_second_post)
            second_post.reload
            expect(second_post.main_post).to be(false)
          end
        end

        context 'when main-post is true' do
          it 'changes from true to false' do
            get(action, params: params_status_false_third_post)
            third_post.reload
            expect(third_post.main_post).to be(false)
          end

          it 'doesnt change' do
            get(action, params: params_status_true_third_post)
            third_post.reload
            expect(third_post.main_post).to be(true)
          end
        end
      end

      context 'with invalid attributes' do
        it 'does not update the post' do
          expect(test_post.title).not_to be_nil
        end
      end
    end

    context 'when admin is not signed in' do
      it_behaves_like 'redirects to new_user_session_path'
    end
  end

  describe 'DELETE #destroy' do
    let(:test_post) { create(:post) }
    let(:action) { :destroy }
    let(:params) { { id: test_post.id } }

    context 'when admin is signed in' do
      before do
        admin_user = create(:user, role: :admin)
        sign_in(admin_user)
      end

      it 'deletes the post' do
        post_to_delete = create(:post)
        expect { delete :destroy, params: { id: post_to_delete.id } }.to change(Post, :count).by(-1)
      end
    end

    context 'when admin is not signed in' do
      it_behaves_like 'redirects to new_user_session_path'
    end
  end

  describe 'POST #create' do
    let(:valid_attributes) { attributes_for(:post) }
    let(:invalid_attributes) { attributes_for(:post, title: nil) }
    let(:action) { :create }
    let(:params) { { post: valid_attributes } }

    context 'when admin is signed in' do
      before do
        admin_user = create(:user, role: :admin)
        sign_in(admin_user)
      end

      context 'with valid attributes' do
        it 'creates a new post' do
          expect { post :create, params: { post: valid_attributes } }.to change(Post, :count).by(1)
        end

        it 'redirects to the new post' do
          post :create, params: { post: valid_attributes }
          expected_path = response.location
          expect(response).to redirect_to(expected_path)
        end
      end

      context 'with invalid attributes' do
        it 'does not create a new post' do
          expect { post :create, params: { post: invalid_attributes } }.not_to change(Post, :count)
        end

        it_behaves_like 'unprocessable_entity status'
      end
    end

    context 'when admin is not signed in' do
      it_behaves_like 'redirects to new_user_session_path'
    end
  end

  describe 'private method #post_params' do
    let(:tag_first) { create(:tag) }
    let(:tag_second) { create(:tag) }

    before do
      admin_user = create(:user, role: :admin)
      sign_in(admin_user)
    end

    it 'permits the expected parameters' do
      test_post = create(:post, tag_ids: [tag_first.id, tag_second.id])

      params = {
        post: {
          title: test_post.title,
          subtitle: test_post.subtitle,
          description_uk: test_post.rich_body(:uk).body.to_s,
          description_en: test_post.rich_body(:en).body.to_s,
          status: test_post.status,
          main_post: test_post.main_post,
          photo: test_post.photo,
          tag_ids: [tag_first.id, tag_second.id]
        }
      }

      controller.params = params
      permitted_params = controller.__send__(:post_params)
      expected_params = ActionController::Parameters.new(
        post: {
          title: test_post.title,
          subtitle: test_post.subtitle,
          description_uk: test_post.rich_body(:uk).body.to_s,
          description_en: test_post.rich_body(:en).body.to_s,
          status: test_post.status,
          main_post: test_post.main_post,
          photo: test_post.photo,
          tag_ids: [tag_first.id, tag_second.id]
        }
      )

      expect(permitted_params).to eq(expected_params.require(:post).permit(:title, :subtitle, :description_uk,
                                                                           :description_en, :status, :main_post,
                                                                           :photo, tag_ids: []))
    end
  end

  # The rest of this file does not render views, so nothing here would have caught the form
  # still calling the TinyMCE helpers after the gem left.
  describe 'the post form' do
    render_views

    before { sign_in(create(:user, role: :admin)) }

    it 'renders one Action Text editor per locale and no TinyMCE' do
      get :new

      expect(response.body).to include('trix-editor')
      I18n.available_locales.each do |locale|
        expect(response.body).to include("post_description_#{locale}")
      end
      expect(response.body).not_to include('tinymce')
    end

    it 'offers the slash menu with every block kind' do
      get :new

      expect(response.body).to include('aitranslation', 'slash-menu', 'post-editor')
      JournalBlock::KINDS.each { |kind| expect(response.body).to include(%(data-kind="#{kind}")) }
    end
  end

  # The list screen: filter rail, search, server-side sorting, and the language-pair indicator
  # the handoff singles out as the one new affordance worth adding.
  describe 'the list screen' do
    render_views

    let(:admin) { create(:user, role: :admin) }

    let!(:published) { bilingual(entry_number: 11, updated_at: 2.days.ago) }
    let!(:hidden) { bilingual(:inactive, entry_number: 12, updated_at: 1.day.ago) }

    before { sign_in(admin) }

    # Real posts carry both languages; the factory only fills the locale it runs in.
    def bilingual(*traits, **attributes)
      post = I18n.with_locale(:en) { create(:post, *traits, **attributes) }
      I18n.with_locale(:uk) { post.update!(title: 'Заголовок', subtitle: 'Лід') }
      post
    end

    it 'shows every post and counts the two states it has' do
      get :index, params: { locale: 'en' }

      expect(response.body.scan('class="mg-title"').size).to eq(2)
      expect(response.body).to include('mg-status--active', 'mg-status--inactive')
    end

    it 'filters by status' do
      get :index, params: { locale: 'en', status: 'inactive' }

      expect(response.body.scan('class="mg-title"').size).to eq(1)
      expect(response.body).to include(hidden.slug)
      expect(response.body).not_to include(published.slug)
    end

    it 'ignores a status that is not one of the two' do
      get :index, params: { locale: 'en', status: 'archived' }

      expect(response.body.scan('class="mg-title"').size).to eq(2)
    end

    it 'searches titles and bodies' do
      I18n.with_locale(:en) { published.update!(title: 'A findable heading', subtitle: 'lede') }

      get :index, params: { locale: 'en', query: 'findable' }

      expect(response.body).to include(published.slug)
      expect(response.body).not_to include(hidden.slug)
    end

    it 'says so when a search finds nothing' do
      get :index, params: { locale: 'en', query: 'nothing-matches-this' }

      expect(response.body).to include('mg-empty')
    end

    # The whitelist is the point: a column name from the query string must never reach ORDER BY.
    it 'sorts only by the columns it allows' do
      get :index, params: { locale: 'en', sort: 'number', direction: 'asc' }

      expect(response.body.index(published.slug)).to be < response.body.index(hidden.slug)

      get :index, params: { locale: 'en', sort: 'number', direction: 'desc' }

      expect(response.body.index(hidden.slug)).to be < response.body.index(published.slug)
    end

    it 'falls back to the default sort when asked for a column it does not allow' do
      get :index, params: { locale: 'en', sort: 'id); drop table posts;--' }

      expect(response).to have_http_status(:success)
      # Default is updated_at desc, so the more recently touched row comes first.
      expect(response.body.index(hidden.slug)).to be < response.body.index(published.slug)
    end

    it 'shows which languages each post is finished in' do
      published.post_translations.find_by(locale: 'en').update!(subtitle: nil)

      get :index, params: { locale: 'en' }

      expect(response.body.scan('mg-lang is-present').size).to eq(3)
    end
  end

  describe 'autosave' do
    let(:admin) { create(:user, role: :admin) }
    let(:post_record) { I18n.with_locale(:en) { create(:post, title: 'A title', subtitle: 'A lede') } }

    def autosave(overrides = {})
      patch :autosave, params: {
        locale: 'en', id: post_record.id,
        post: {
          lock_version: post_record.lock_version, title: 'A title', subtitle: 'A lede',
          status: 'active'
        }.merge(overrides)
      }
    end

    before { sign_in(admin) }

    it 'saves and reports the version the editor should keep' do
      autosave(subtitle: 'A better lede')

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['status']).to eq('saved')
      expect(response.parsed_body['lock_version']).to be > post_record.lock_version
      expect(response.parsed_body['at']).to match(/\A\d{2}:\d{2}:\d{2}\z/)
      expect(I18n.with_locale(:en) { post_record.reload.subtitle }).to eq('A better lede')
    end

    # The conflict is detected by the real lock_version, which is why the banner means
    # something: on 409 nothing has been written.
    it 'refuses a stale version and writes nothing' do
      stale = post_record.lock_version
      I18n.with_locale(:en) { post_record.update!(subtitle: 'saved by someone else') }

      patch :autosave, params: {
        locale: 'en', id: post_record.id,
        post: { lock_version: stale, title: 'A title', subtitle: 'mine' }
      }

      expect(response).to have_http_status(:conflict)
      expect(response.parsed_body['status']).to eq('conflict')
      expect(I18n.with_locale(:en) { post_record.reload.subtitle }).to eq('saved by someone else')
    end

    # A post needs a title, a lede and a body in the locale being edited before it can be
    # saved at all, so "invalid" is a real state of this screen rather than a failure.
    it 'says what is missing instead of pretending to save' do
      autosave(title: '')

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['status']).to eq('invalid')
      expect(response.parsed_body['errors']).to be_present
      expect(I18n.with_locale(:en) { post_record.reload.title }).to eq('A title')
    end

    it 'is closed to a moderator, like update is' do
      sign_in(create(:user, role: :moderator))

      expect { autosave(subtitle: 'from a moderator') }
        .not_to(change { I18n.with_locale(:en) { post_record.reload.subtitle } })
    end
  end

  describe 'the slug' do
    let(:admin) { create(:user, role: :admin) }
    let(:post_record) { I18n.with_locale(:en) { create(:post, title: 'A title', subtitle: 'A lede') } }

    before { sign_in(admin) }

    # It used to be overwritten from the English title on every save, which made the slug field
    # in the meta panel a lie.
    it 'keeps the one the editor wrote' do
      patch :update, params: {
        locale: 'en', id: post_record.id,
        post: { title: 'A title', subtitle: 'A lede', slug: 'chosen-by-hand' }
      }

      expect(post_record.reload.slug).to eq('chosen-by-hand')
    end

    it 'derives one from the English title when the field is left empty' do
      patch :update, params: {
        locale: 'en', id: post_record.id,
        post: { title: 'A Brand New Title', subtitle: 'A lede', slug: '' }
      }

      expect(post_record.reload.slug).to eq('a-brand-new-title')
    end
  end

  describe 'the featured flag' do
    let(:admin) { create(:user, role: :admin) }
    let(:post_record) { I18n.with_locale(:en) { create(:post, title: 'A title', subtitle: 'A lede') } }

    before { sign_in(admin) }

    # The editor posts true/false. The old comparison was against "active", so this select
    # could never turn the flag on.
    it 'turns on from the value the editor posts' do
      patch :update, params: {
        locale: 'en', id: post_record.id,
        post: { title: 'A title', subtitle: 'A lede', main_post: 'true' }
      }

      expect(post_record.reload.main_post).to be(true)
    end

    # A request that does not mention the flag must not silently unfeature the post.
    it 'is left alone by a request that does not mention it' do
      post_record.update_columns(main_post: true)

      patch :update, params: {
        locale: 'en', id: post_record.id,
        post: { title: 'A title', subtitle: 'Another lede' }
      }

      expect(post_record.reload.main_post).to be(true)
    end
  end

  describe 'preview' do
    render_views

    let(:admin) { create(:user, role: :admin) }
    let(:post_record) do
      I18n.with_locale(:en) { create(:post, title: 'A title', subtitle: 'A lede', description_en: '<p>Body copy.</p>') }
    end

    before { sign_in(admin) }

    # The pane is worth having only if it is the article, so it renders through the public
    # page's own helper and classes.
    it 'renders the article with the classes the public page uses' do
      get :preview, params: { locale: 'en', id: post_record.id }

      expect(response.body).to include('jn-post', 'jn-body', 'jn-body__lede')
      expect(response.body).to include('Body copy.')
    end
  end
end
