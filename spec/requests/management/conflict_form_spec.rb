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

  def form_lock_version
    response.parsed_body.at_css('input[name="post[lock_version]"]')['value'].to_i
  end

  # A second editor can still race a Save; that is a conflict to show, not a 500.
  describe 'a Save that arrives with a stale version' do
    let!(:stale) { post_record.lock_version }

    before { I18n.with_locale(:en) { post_record.update!(subtitle: 'saved by somebody else') } }

    def save(version, **fields)
      patch management_post_path(post_record, locale: 'en'),
            params: { post: { title: 'A title', subtitle: 'mine', lock_version: version, **fields } }
    end

    it 'answers with the conflict rather than raising' do
      expect { save(stale) }.not_to raise_error

      expect(response).to have_http_status(:conflict)
      expect(response.body).to include(I18n.t('management.posts.update.conflict', locale: :en))
    end

    it 'leaves the record alone and gives the editor the version that is current' do
      save(stale)

      expect(I18n.with_locale(:en) { post_record.reload.subtitle }).to eq('saved by somebody else')
      expect(form_lock_version).to eq(post_record.lock_version)
    end

    # The notice says the work is still here and Save will take it, so it has to be.
    it 'gives the author back what they typed, over the version that is current' do
      save(stale, title: 'TYPED TITLE', subtitle: 'TYPED LEDE', description_en: '<p>TYPED BODY</p>')

      expect(response).to have_http_status(:conflict)
      expect(response.body).to include('TYPED TITLE', 'TYPED LEDE', 'TYPED BODY')
      expect(form_lock_version).to eq(post_record.reload.lock_version)
    end

    it 'takes the work on the next Save' do
      save(stale)
      save(form_lock_version)

      expect(response).to redirect_to(management_posts_path)
      expect(I18n.with_locale(:en) { post_record.reload.subtitle }).to eq('mine')
    end
  end

  # The other language is refused after the post is written, in the same transaction.
  describe 'a Save the other language refuses' do
    def save(version, uk_title)
      patch management_post_path(post_record, locale: 'en'), params: {
        post: {
          lock_version: version, title: 'A title', subtitle: 'A lede', description_en: '<p>Typed body</p>',
          title_localizations: { uk: uk_title }, subtitle_localizations: { uk: 'Лід' }
        }
      }
    end

    it 'puts the version it was loaded at back in the form, with what was typed' do
      loaded = post_record.lock_version

      save(loaded, '')

      expect(response).to have_http_status(:unprocessable_content)
      expect(form_lock_version).to eq(loaded)
      expect(response.body).to include('Typed body')
    end

    it 'goes through once it is corrected, with the version the form showed' do
      save(post_record.lock_version, '')
      save(form_lock_version, 'Заголовок')

      expect(response).to redirect_to(management_posts_path)
      expect(post_record.reload.rich_body(:en).body.to_plain_text).to eq('Typed body')
    end
  end
end
