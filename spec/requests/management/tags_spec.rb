# frozen_string_literal: true

require 'rails_helper'

# Signed out is in anonymous_access_spec; refused writes and Turbo Streams in action_feedback_spec.
describe 'the admin tag screens', type: :request do
  let(:tag) { create(:tag, title: 'before') }

  before { sign_in create(:user, role: :admin) }

  it 'renders the list, the new form and the edit form' do
    [
      management_tags_path(locale: 'uk'), new_management_tag_path(locale: 'uk'),
      edit_management_tag_path(tag, locale: 'uk')
    ].each do |path|
      get path

      expect(response).to have_http_status(:ok), path
    end
  end

  it 'creates a tag and goes back to the list' do
    expect { post management_tags_path(locale: 'uk'), params: { tag: { title: 'shipping' } } }
      .to change(Tag, :count).by(1)

    expect(response).to redirect_to(management_tags_path)
    expect(response).to have_http_status(:see_other)
    expect(flash[:success]).to eq(I18n.t('management.tags.create.success', locale: :uk))
  end

  it 'does not create a tag without a title' do
    expect { post management_tags_path(locale: 'uk'), params: { tag: { title: '' } } }
      .not_to change(Tag, :count)
  end

  it 'renames a tag' do
    patch management_tag_path(tag, locale: 'uk'), params: { tag: { title: 'Updated Title' } }

    expect(response).to redirect_to(management_tags_path)
    expect(tag.reload.title).to eq('Updated Title')
  end

  it 'deletes a tag with a 303, so the browser follows with a GET' do
    tag

    expect { delete management_tag_path(tag, locale: 'uk') }.to change(Tag, :count).by(-1)

    expect(response).to have_http_status(:see_other)
  end
end
