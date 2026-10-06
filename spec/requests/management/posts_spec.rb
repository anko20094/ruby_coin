# frozen_string_literal: true

require 'rails_helper'

# Create, update and destroy of a post. Signed-out redirects for every route are in
# anonymous_access_spec; what a refused save says is in action_feedback_spec.
describe 'the admin post screens', type: :request do
  include_context 'when carrierwave cleanup'

  let(:admin) { create(:user, role: :admin) }
  let(:test_post) { create(:post) }

  context 'when admin is signed in' do
    before { sign_in(admin) }

    it 'renders the list, the new form and the edit form' do
      [
        management_posts_path(locale: 'uk'), new_management_post_path(locale: 'uk'),
        edit_management_post_path(test_post, locale: 'uk')
      ].each do |path|
        get path

        expect(response).to have_http_status(:ok), path
      end
    end

    describe 'PATCH /management/posts/:id' do
      def feature(post_record, value)
        patch management_post_path(post_record, locale: 'uk'), params: { post: { main_post: value } }
        post_record.reload
      end

      it 'updates the post and goes back to the list' do
        patch management_post_path(test_post.slug, locale: 'uk'), params: { post: { title: 'Updated Title' } }

        expect(response).to redirect_to(management_posts_path)
        expect(flash[:success]).to eq(I18n.t('management.posts.update.success', locale: :uk))
        expect(test_post.reload.title).to eq('Updated Title')
      end

      it 'turns the featured flag on and off, and leaves it as it was when it is resent' do
        expect(feature(create(:post, main_post: false), 'true').main_post).to be(true)
        expect(feature(create(:post, main_post: false), 'false').main_post).to be(false)
        expect(feature(create(:post, main_post: true), 'false').main_post).to be(false)
        expect(feature(create(:post, main_post: true), 'true').main_post).to be(true)
      end

      # A request that does not mention the flag must not silently unfeature the post.
      it 'leaves the featured flag alone when the request does not mention it' do
        test_post.update_columns(main_post: true)

        patch management_post_path(test_post, locale: 'uk'), params: { post: { subtitle: 'Another lede' } }

        expect(test_post.reload.main_post).to be(true)
      end

      it 'writes nothing when the title is blank' do
        original = test_post.title

        patch management_post_path(test_post.slug, locale: 'uk'), params: { post: { title: '' } }

        expect(response).to have_http_status(:unprocessable_content)
        expect(test_post.reload.title).to eq(original)
      end

      it 'writes the fields the editor sends and ignores the ones it does not own' do
        tags = create_list(:tag, 2)
        photo = Rack::Test::UploadedFile.new(Rails.root.join('spec', 'fixtures', 'files', 'pixel.png'), 'image/png')
        old_photo = test_post.photo.identifier

        patch management_post_path(test_post, locale: 'uk'), params: {
          post: {
            title: 'Новий заголовок', subtitle: 'Новий лід', description_uk: '<p>Тіло</p>',
            description_en: '<p>Body</p>', status: 'inactive', main_post: 'true', photo:,
            tag_ids: tags.map(&:id), entry_number: 999_999
          }
        }

        test_post.reload
        expect(response).to redirect_to(management_posts_path)
        expect(I18n.with_locale(:uk) { [test_post.title, test_post.subtitle] }).to eq(['Новий заголовок', 'Новий лід'])
        expect(test_post.rich_body(:uk).body.to_plain_text).to eq('Тіло')
        expect(test_post.rich_body(:en).body.to_plain_text).to eq('Body')
        expect(test_post).to be_inactive.and be_main_post
        expect(test_post.photo.identifier).not_to eq(old_photo)
        expect(test_post.tag_ids).to match_array(tags.map(&:id))
        expect(test_post.entry_number).not_to eq(999_999)
      end
    end

    it 'deletes a post' do
      test_post

      expect { delete management_post_path(test_post, locale: 'uk') }.to change(Post, :count).by(-1)

      expect(response).to redirect_to(management_posts_path)
      expect(response).to have_http_status(:see_other)
    end

    describe 'POST /management/posts' do
      it 'creates a post and goes back to the list' do
        expect { post management_posts_path(locale: 'uk'), params: { post: attributes_for(:post) } }
          .to change(Post, :count).by(1)

        expect(response).to redirect_to(management_posts_path)
        expect(Post.last.user).to eq(admin)
      end

      it 'does not create a post without a title' do
        expect { post management_posts_path(locale: 'uk'), params: { post: attributes_for(:post, title: nil) } }
          .not_to change(Post, :count)
      end
    end

    # The post and its other-language rows are one save, and a refused create is still a new post.
    describe 'a create the other language refuses' do
      let(:attributes) do
        attributes_for(:post).merge(title: 'English title', slug: '', title_localizations: { uk: '' })
      end

      def create_post(locale, attributes) = post(management_posts_path(locale:), params: { post: attributes })

      it 'writes nothing at all' do
        expect { create_post('en', attributes) }
          .not_to(change { [Post.count, PostTranslation.count, FriendlyId::Slug.count] })

        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'comes back as a form for a post that is not saved yet' do
        create_post('en', attributes)

        expect(response.body).not_to include('post[lock_version]')
        expect(response.body).to include('English title')
      end

      it 'can be sent again, corrected' do
        create_post('en', attributes)

        expect { create_post('en', attributes.merge(title_localizations: { uk: 'Заголовок' })) }
          .to change(Post, :count).by(1)

        expect(Post.last.slug).to eq('english-title')
      end

      it 'can be refused twice without raising' do
        refused = attributes.merge(title_localizations: { en: '' })

        expect { 2.times { create_post('uk', refused) } }.not_to raise_error
      end
    end
  end

  context 'when nobody is signed in' do
    it 'updates nothing' do
      original = test_post.title

      patch management_post_path(test_post.slug, locale: 'uk'), params: { post: { title: 'Updated Title' } }

      expect(response).to redirect_to(new_user_session_path)
      expect(test_post.reload.title).to eq(original)
    end

    it 'deletes nothing' do
      test_post

      expect { delete management_post_path(test_post, locale: 'uk') }.not_to change(Post, :count)
    end

    it 'creates nothing' do
      expect { post management_posts_path(locale: 'uk'), params: { post: attributes_for(:post) } }
        .not_to change(Post, :count)
    end
  end
end
