# frozen_string_literal: true

require 'rails_helper'

# Whether the admin tells the truth about what just happened.
#
# Six separate defects met here: a Turbo Stream aimed at an element that is rendered nowhere,
# two screens that reported nothing at all on a failed save, a 422 carrying a Location header,
# and an authorization message that printed a Ruby class name at the reader. Each one made the
# screen claim an outcome that had not happened, which is worse than saying nothing.
describe 'what the admin says after an action' do
  describe 'the Turbo Stream flash' do
    before { sign_in create(:user, role: :admin) }

    # `turbo_stream.prepend 'flash'` targeted an id that exists in no template. Turbo drops a
    # stream whose target is missing without a word, so every tag write acknowledged nothing.
    it 'targets the frame the layout actually renders' do
      tag = create(:tag)

      delete "/en/management/tags/#{tag.id}", as: :turbo_stream

      expect(response.body).to include('target="flash_message"')
      expect(response.body).not_to include('target="flash"')
    end

    it 'carries the message into the stream, not just an empty frame' do
      post '/en/management/tags', params: { tag: { title: 'shipping' } }, as: :turbo_stream

      expect(response.body).to include(I18n.t('management.tags.create.success', locale: :en))
    end

    # The failure branch is the one that mattered: the row is not prepended *and* the alert was
    # thrown away, so a blank title looked identical to a successful save.
    it 'reports a failed create instead of rendering nothing' do
      expect { post '/en/management/tags', params: { tag: { title: '' } }, as: :turbo_stream }
        .not_to change(Tag, :count)

      expect(response.body).to include('target="flash_message"')
      # The body is a stream template, so the message arrives HTML-escaped.
      expect(CGI.unescapeHTML(response.body))
        .to include(I18n.with_locale(:en) { Tag.new.tap(&:valid?).errors.full_messages.first })
    end

    # The guard used to read `@tag.title.present?`, which only stands in for "saved" while
    # presence is Tag's single validation. Add any other rule and an invalid tag joins the list.
    it 'does not prepend a row for a tag that was not saved' do
      post '/en/management/tags', params: { tag: { title: '' } }, as: :turbo_stream

      expect(response.body).not_to include('target="tags"')
    end
  end

  describe 'a failed tag write without Turbo' do
    before { sign_in create(:user, role: :admin) }

    # 422 is not a redirect status, so the browser never followed the Location header: the
    # author landed on Rails' bare "You are being redirected" with the typed title gone.
    it 'renders the form again rather than answering 422 with a Location' do
      post '/en/management/tags', params: { tag: { title: '' } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.headers['Location']).to be_nil
      expect(response.parsed_body.at_css('form')).to be_present
    end

    it 'keeps the rest of the screen usable — the list is still there' do
      create(:tag, title: 'existing')

      post '/en/management/tags', params: { tag: { title: '' } }

      expect(response.body).to include('existing')
    end

    it 'does the same for a failed update' do
      tag = create(:tag, title: 'before')

      patch "/en/management/tags/#{tag.id}", params: { tag: { title: '' } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.headers['Location']).to be_nil
      expect(tag.reload.title).to eq('before')
    end

    def refuse_saving_tags
      allow_any_instance_of(Tag).to receive(:valid?) do |tag|
        tag.errors.add(:title, :taken)
        false
      end
    end

    def blank_title_error = "Title #{I18n.t('errors.messages.blank', locale: :en)}"

    # The create form was built from Tag.new, so what had been typed and why it was refused
    # were both gone.
    it 'keeps what was typed in the create form and says why it was refused' do
      refuse_saving_tags

      post '/en/management/tags', params: { tag: { title: 'kept title' } }

      form = response.parsed_body.at_css('form.mg-tag-create')
      expect(form.at_css('input[name="tag[title]"]')['value']).to eq('kept title')
      expect(response.parsed_body.at_css('#new_tag [role="alert"]').text).to include('Title')
    end

    it 'shows a failed rename on that tag, with what was typed and the error' do
      tag = create(:tag, title: 'before')
      refuse_saving_tags

      patch "/en/management/tags/#{tag.id}", params: { tag: { title: 'after' } }

      row = response.parsed_body.at_css("#tag_#{tag.id}")
      expect(row.at_css('input[name="tag[title]"]')['value']).to eq('after')
      expect(row.at_css('[role="alert"]')).to be_present
      expect(response.parsed_body.at_css('#new_tag [role="alert"]')).to be_nil
      expect(response.parsed_body.css("#tag_#{tag.id}").size).to eq(1)
    end

    it 'shows a failed rename of a tag that is not on the first page above the list' do
      tag = create(:tag, title: 'old one', created_at: 1.year.ago)
      create_list(:tag, 8)

      patch "/en/management/tags/#{tag.id}", params: { tag: { title: '' } }

      row = response.parsed_body.at_css("#tag_#{tag.id}")
      expect(row.at_css('[role="alert"]').text).to include(blank_title_error)
    end
  end

  describe 'a failed post save' do
    let(:admin) { create(:user, role: :admin) }
    let(:existing) { create(:post, user: admin) }

    before { sign_in admin }

    # The editor rendered no error region at all, so a rejected Save came back byte-similar to
    # the form you submitted — and the state indicator above it still read "no changes".
    def reject_a_save
      patch "/en/management/posts/#{existing.id}",
            params: { post: { title: '', lock_version: existing.lock_version } }
    end

    it 'shows what was wrong' do
      reject_a_save

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.at_css('[role="alert"] li')).to be_present
    end

    it 'stops the state indicator claiming there is nothing to save' do
      reject_a_save
      state = response.parsed_body.at_css('[data-post-editor-target="state"]')

      expect(state['data-state']).to eq('invalid')
      expect(state.text).not_to include(I18n.t('management.posts.editor.state.clean', locale: :en))
    end

    # #persist rolls both writes back in one transaction, and the other locale's boxes were
    # then re-read from the database — so a rejected save quietly restored the pre-edit text.
    # The request is /en, so uk is the *other* language — the one drawn through #current_data.
    it 'gives the other language back what was typed into it, not what the database still holds' do
      existing.translations.find_or_initialize_by(locale: 'uk')
              .update!(title: 'stored in the database')

      patch "/en/management/posts/#{existing.id}", params: {
        post: {
          title: '', lock_version: existing.lock_version,
          title_localizations: { 'uk' => 'typed just now, and rejected' }
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('typed just now, and rejected')
      expect(response.body).not_to include('stored in the database')
    end
  end

  describe 'an authorization refusal' do
    # Pundit's own message names the policy class and the query. It went into the flash
    # verbatim, which also meant the translated string below could never be reached.
    it 'speaks the reader’s language instead of naming a Ruby class' do
      sign_in create(:user, role: :user)

      get '/uk/management/posts'

      expect(flash[:alert]).to eq(I18n.t('application_controller.alert', locale: :uk))
      expect(flash[:alert]).not_to include('Policy')
    end
  end

  describe 'the error list' do
    before { sign_in create(:user, role: :admin) }

    # It carried `data-controller="flash"`, whose only job is to delete its element after six
    # seconds — on a form four thousand pixels tall, that is shorter than the scroll to the
    # first bad field.
    it 'does not wire itself up to self-destruct' do
      post '/en/management/cases', params: { case: { slug: '', mark: '', position: '' } }
      alert = response.parsed_body.at_css('[role="alert"]')

      expect(alert).to be_present
      expect(alert['data-controller']).to be_nil
    end
  end
end
