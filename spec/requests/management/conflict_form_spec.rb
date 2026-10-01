# frozen_string_literal: true

require 'rails_helper'

describe 'the post form re-rendered after a refused save', type: :request do
  include_context 'when carrierwave cleanup'

  let(:post_record) { I18n.with_locale(:en) { create(:post, title: 'A title', subtitle: 'A lede') } }
  let(:form) { response.parsed_body.at_css('form[data-controller~="post-editor"]') }

  before { sign_in create(:user, role: :admin) }

  def stale_save
    stale = post_record.lock_version
    I18n.with_locale(:en) { post_record.update!(subtitle: 'saved by someone else') }
    patch management_post_path(post_record, locale: 'en'),
          params: { post: { lock_version: stale, title: 'A title', subtitle: 'mine' } }
  end

  it 'holds the unsaved work behind the leave-page guard after a conflict' do
    stale_save

    expect(response).to have_http_status(:conflict)
    expect(form['data-unsaved-guard-dirty-value']).to eq('true')
  end

  it 'stops autosaving after a conflict, so only an explicit Save overwrites the other editor' do
    stale_save

    expect(form['data-post-editor-autosave-url-value']).to be_nil
  end

  it 'keeps autosave on a freshly opened form' do
    get edit_management_post_path(post_record, locale: 'en')

    expect(form['data-post-editor-autosave-url-value']).to end_with('/autosave')
    expect(form['data-unsaved-guard-dirty-value']).to eq('false')
  end
end
