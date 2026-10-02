# frozen_string_literal: true

require 'rails_helper'

describe 'PATCH /management/posts/:id/autosave', type: :request do
  include_context 'when carrierwave cleanup'

  let(:post_record) { I18n.with_locale(:en) { create(:post, title: 'A title', subtitle: 'A lede') } }

  before { sign_in create(:user, role: :admin) }

  def autosave(overrides = {})
    patch autosave_management_post_path(post_record, locale: 'en'), params: {
      post: {
        lock_version: post_record.lock_version, title: 'A title', subtitle: 'A lede', status: 'active'
      }.merge(overrides)
    }
  end

  def saved_by_someone_else
    stale = post_record.lock_version
    I18n.with_locale(:en) { post_record.update!(subtitle: 'saved by someone else') }
    stale
  end

  it 'saves and reports the version the editor should keep' do
    autosave(subtitle: 'A better lede')

    expect(response).to have_http_status(:success)
    expect(response.parsed_body['status']).to eq('saved')
    expect(response.parsed_body['lock_version']).to be > post_record.lock_version
    expect(response.parsed_body['at']).to match(/\A\d{2}:\d{2}:\d{2}\z/)
    expect(I18n.with_locale(:en) { post_record.reload.subtitle }).to eq('A better lede')
  end

  it 'leaves the tags alone when the save is refused as stale or invalid' do
    kept = create(:tag)
    other = create(:tag)
    I18n.with_locale(:en) { post_record.update!(tag_ids: [kept.id]) }
    stale = saved_by_someone_else

    autosave(lock_version: stale, tag_ids: ['', other.id.to_s])
    expect(response).to have_http_status(:conflict)

    autosave(lock_version: post_record.reload.lock_version, title: '', tag_ids: ['', other.id.to_s])
    expect(response).to have_http_status(:unprocessable_content)

    expect(post_record.reload.tag_ids).to eq([kept.id])
  end

  # The conflict is detected by the real lock_version, so on 409 nothing has been written.
  it 'refuses a stale version and writes nothing' do
    stale = saved_by_someone_else

    patch autosave_management_post_path(post_record, locale: 'en'),
          params: { post: { lock_version: stale, title: 'A title', subtitle: 'mine' } }

    expect(response).to have_http_status(:conflict)
    expect(response.parsed_body['status']).to eq('conflict')
    expect(I18n.with_locale(:en) { post_record.reload.subtitle }).to eq('saved by someone else')
  end

  # A post must be valid in the edited locale to save at all, so "invalid" is a real state.
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

  # The post write and the translation write are one save, so "invalid" means nothing landed.
  it 'writes nothing when the other language fails validation' do
    before_title = I18n.with_locale(:en) { post_record.title }

    autosave(title: 'A renamed title', title_localizations: { uk: '' })

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body['status']).to eq('invalid')
    expect(I18n.with_locale(:en) { post_record.reload.title }).to eq(before_title)
  end

  # A refused save keeps the editor on the version its content was loaded at.
  it 'hands out no version for a save that wrote nothing' do
    autosave(title: 'A renamed title', title_localizations: { uk: '' })

    expect(response.parsed_body).not_to have_key('lock_version')
  end

  it 'still answers a stale form with a conflict once the refused field is corrected' do
    stale = post_record.lock_version
    I18n.with_locale(:en) { post_record.update!(description_en: '<p>Written in the other tab</p>') }

    autosave(lock_version: stale, subtitle: '')
    expect(response).to have_http_status(:unprocessable_content)
    held = response.parsed_body.fetch('lock_version') { stale }

    autosave(lock_version: held, subtitle: 'A lede, corrected')

    expect(response).to have_http_status(:conflict)
    expect(post_record.reload.rich_body(:en).body.to_plain_text).to eq('Written in the other tab')
  end

  it 'reports the version the database holds after a save' do
    autosave(title: 'A renamed title', title_localizations: { uk: 'Нова назва' })

    expect(response.parsed_body['lock_version']).to eq(post_record.reload.lock_version)
  end

  it 'does not hand a conflict a version to adopt' do
    autosave(lock_version: saved_by_someone_else, subtitle: 'mine')

    expect(response.parsed_body).not_to have_key('lock_version')
  end

  # Only a Save names a URL: a slug being typed is a different slug at every pause.
  it 'does not move the slug of a published post while it is being typed' do
    original = post_record.slug

    %w[half-typ half-typed half-typed-slug].each { |typed| autosave(title: 'A title', slug: typed) }
    autosave(title: 'Halfway through a rename', slug: '')

    expect(post_record.reload.slug).to eq(original)
    expect(post_record.slugs.count).to eq(1)
  end

  # Changes no column on posts, so nothing else would check the version or move updated_at.
  it 'counts an edit of only the other language as a write' do
    expect { autosave(title_localizations: { uk: 'Тільки українська' }) }
      .to change { post_record.reload.lock_version }.and(change { post_record.reload.updated_at })

    expect(response).to have_http_status(:success)
  end

  it 'refuses the second of two editors who both only changed the other language' do
    loaded = post_record.lock_version

    autosave(lock_version: loaded, title_localizations: { uk: 'Перший редактор' })
    autosave(lock_version: loaded, title_localizations: { uk: 'Другий редактор' })

    expect(response).to have_http_status(:conflict)
    expect(post_record.translations.find_by(locale: 'uk').title).to eq('Перший редактор')
  end
end
