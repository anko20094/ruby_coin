# frozen_string_literal: true

require 'rails_helper'

# The slug in the meta panel is the editor's to set; only a create derives one.
describe 'the slug a post Save writes', type: :request do
  include_context 'when carrierwave cleanup'

  let(:post_record) { I18n.with_locale(:en) { create(:post, title: 'A title', subtitle: 'A lede') } }

  before { sign_in create(:user, role: :admin) }

  def put_slug(slug, title: 'A title')
    patch management_post_path(post_record, locale: 'en'), params: { post: { title:, subtitle: 'A lede', slug: } }
  end

  def create_post(attributes)
    post management_posts_path(locale: 'en'), params: { post: attributes_for(:post).merge(attributes) }
  end

  it 'keeps the one the editor wrote' do
    put_slug('chosen-by-hand')

    expect(post_record.reload.slug).to eq('chosen-by-hand')
  end

  it 'derives one from the English title for a post being created' do
    expect { create_post(title: 'A Brand New Title', slug: '') }.to change(Post, :count).by(1)

    expect(Post.order(:created_at).last.slug).to eq('a-brand-new-title')
  end

  # An empty box on an existing post means "leave the URL alone", not "regenerate it".
  it 'leaves a published post at the URL it already has when the field is emptied' do
    original = post_record.slug

    put_slug('', title: 'A Brand New Title')

    expect(post_record.reload.slug).to eq(original)
  end

  it 'gives a second post with the same English title a slug of its own' do
    expect { 2.times { create_post(title: 'Same Title', slug: '') } }.to change(Post, :count).by(2)

    expect(Post.order(:id).last(2).map(&:slug)).to eq(%w[same-title same-title-2])
  end

  it 'does not hand out a slug an earlier post has since moved away from' do
    original = post_record.slug
    put_slug('moved-on')

    create_post(title: 'Anything', slug: original)

    expect(response).to have_http_status(:unprocessable_content)
  end

  it 'refuses a typed slug that another post already has, without raising' do
    taken = I18n.with_locale(:en) { create(:post, title: 'Other', subtitle: 'Other lede') }

    expect { put_slug(taken.slug) }.not_to raise_error

    expect(response).to have_http_status(:unprocessable_content)
    expect(post_record.reload.slug).not_to eq(taken.slug)
  end

  it 'lets a post go back to a slug it used before' do
    original = post_record.slug
    put_slug('moved-on')
    put_slug(original)

    expect(post_record.reload.slug).to eq(original)
  end
end
