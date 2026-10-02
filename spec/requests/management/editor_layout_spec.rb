# frozen_string_literal: true

require 'rails_helper'

# Two things about the editor's shape, both of which are only true server-side — and both of
# which a browser would show as a flash or a reflow if they were not.
describe 'the /management editor layout' do
  before { sign_in create(:user, role: :admin) }

  describe 'the sidebar rail' do
    # A cookie rather than localStorage, because the admin bundle is deferred and the admin CSP
    # has no inline script: a class stamped by JavaScript lands after first paint, so the
    # sidebar would flash open on every page load before snapping shut.
    it 'starts shut when the cookie says so' do
      cookies[ManagementHelper::SIDEBAR_COOKIE] = 'collapsed'
      get '/en/management/posts'

      expect(response.parsed_body.at_css('.mg-shell')['class']).to include('is-sidebar-collapsed')
    end

    it 'starts open with no cookie, and with any other value' do
      get '/en/management/posts'
      expect(response.parsed_body.at_css('.mg-shell')['class']).not_to include('is-sidebar-collapsed')

      cookies[ManagementHelper::SIDEBAR_COOKIE] = 'open'
      get '/en/management/posts'
      expect(response.parsed_body.at_css('.mg-shell')['class']).not_to include('is-sidebar-collapsed')
    end
  end

  describe 'the post editor' do
    # The meta fields took a fixed 300px out of the middle of the screen for the whole time you
    # were writing. They are a strip under the two columns now.
    it 'puts the meta fields below the columns, not inside them' do
      get '/en/management/posts/new'
      page = response.parsed_body

      expect(page.at_css('.mg-editor__cols .mg-editor__meta')).to be_nil
      expect(page.at_css('.mg-editor .mg-editor__meta')).to be_present

      # And they are still inside the post's own form, or none of them would post.
      meta = page.at_css('.mg-editor__meta')
      expect(meta.ancestors('form').first['action']).to end_with('/management/posts')
      expect(meta.at_css('[name="post[slug]"]')).to be_present
      expect(meta.at_css('[name="post[status]"]')).to be_present
    end
  end

  describe 'the choices on the editor' do
    let(:entry) { create(:post) }

    def pressed(selector)
      response.parsed_body.css(selector).to_h { |button| [button.text.strip, button['aria-pressed']] }
    end

    it 'says which language tab is showing, and that side by side is off' do
      get "/en/management/posts/#{entry.slug}/edit"

      side_by_side = I18n.t('management.posts.editor.side_by_side', locale: :en)

      expect(pressed('.mg-tab')).to eq('en' => 'true', 'uk' => 'false', side_by_side => 'false')
    end

    it 'says which preview width is showing' do
      get "/en/management/posts/#{entry.slug}/edit"

      expect(pressed('.mg-preview__width')).to eq('desktop' => 'true', 'mobile' => 'false')
    end
  end

  describe 'the guard against leaving with unsaved edits' do
    let(:entry) { create(:post) }
    let(:form) { response.parsed_body.at_css('form[data-controller~="post-editor"]') }

    def controllers = form['data-controller'].split

    # post-editor is the one judge of what an edit is; the guard listens to it, not the fields.
    it 'protects a new post, which has no autosave to do it' do
      get '/en/management/posts/new'

      expect(controllers).to include('unsaved-guard', 'post-editor')
      expect(form['data-post-editor-autosave-url-value']).to be_nil
      expect(form['data-action']).to include('post-editor:dirty->unsaved-guard#mark', 'submit->unsaved-guard#release')
      expect(form['data-action']).not_to include('input->unsaved-guard#mark')
      expect(form['data-unsaved-guard-dirty-value']).to eq('false')
    end

    it 'lifts the guard when an autosave lands, on the post being edited' do
      get "/en/management/posts/#{entry.slug}/edit"

      expect(controllers).to include('unsaved-guard', 'post-editor')
      expect(form['data-action']).to include('post-editor:saved->unsaved-guard#release')
    end

    it 'starts armed when a failed Save puts the typed text back on the page' do
      post '/en/management/posts', params: { post: { title: '' } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(form['data-unsaved-guard-dirty-value']).to eq('true')
    end
  end

  # The preview is of one language and it has to be the one the tab is on. It used to render in
  # whatever language the admin's own chrome was in, whichever tab was open — so an editor
  # writing Ukrainian watched an English preview, with nothing on the pane saying which.
  describe 'the preview pane' do
    let(:post) do
      create(:post, description_en: '<p>the english body</p>', description_uk: '<p>тіло українською</p>')
    end

    it 'renders the language it is asked for' do
      get "/en/management/posts/#{post.slug}/preview", params: { preview_locale: 'uk' }

      expect(response.body).to include('тіло українською')
      expect(response.body).not_to include('the english body')
      expect(response.parsed_body.at_css('.mg-preview__article')['data-locale']).to eq('uk')
    end

    it 'sets the language of the article, so a reader of it is not given the admin chrome\'s' do
      get "/en/management/posts/#{post.slug}/preview", params: { preview_locale: 'uk' }
      expect(response.parsed_body.at_css('.mg-preview__article')['lang']).to eq('uk')

      get "/uk/management/posts/#{post.slug}/preview", params: { preview_locale: 'en' }
      expect(response.parsed_body.at_css('.mg-preview__article')['lang']).to eq('en')
    end

    it "falls back to the admin's own language when asked for one that does not exist" do
      get "/en/management/posts/#{post.slug}/preview", params: { preview_locale: 'de' }

      expect(response.body).to include('the english body')
      expect(response.parsed_body.at_css('.mg-preview__article')['data-locale']).to eq('en')
    end

    it 'offers a way out to the real page in each language' do
      get "/en/management/posts/#{post.slug}/edit"

      links = response.parsed_body.css('.mg-preview__open').to_h { |a| [a['data-locale'], a['href']] }
      expect(links).to eq('en' => "/en/post/#{post.slug}", 'uk' => "/uk/post/#{post.slug}")
      # One visible at a time; the controller swaps them with the tab.
      expect(response.parsed_body.css('.mg-preview__open:not([hidden])').size).to eq(1)
    end

    # The pane is worth having only if it is the article, so it uses the public page's classes.
    it 'renders the article with the classes the public page uses' do
      entry = I18n.with_locale(:en) do
        create(:post, title: 'A title', subtitle: 'A lede', description_en: '<p>Body copy.</p>')
      end

      get preview_management_post_path(entry, locale: 'en')

      expect(response.body).to include('jn-post', 'jn-body', 'jn-body__lede')
      expect(response.body).to include('Body copy.')
    end
  end

  describe 'the editors on the post form' do
    before { get new_management_post_path(locale: 'uk') }

    # A textarea named after the rich text, not a <trix-editor>: bodies written under Trix still load.
    it 'renders one TinyMCE editor per locale, on the Action Text field' do
      I18n.available_locales.each do |locale|
        field = Post::RICH_TEXT_BODIES.fetch(locale)
        expect(response.body).to match(/<textarea[^>]+name="post\[#{field}\]"/)
        expect(response.body).to include("post_description_#{locale}")
      end

      expect(response.body).to include('data-tinymce-profile-value="post"')
      expect(response.body).not_to include('trix-editor')
    end

    # A javascript: URL is inline script, which the admin's script-src refuses on every click.
    it 'offers the translation as a button, not as a javascript: link' do
      page = response.parsed_body

      expect(page.at_css('button#translation-button')['type']).to eq('button')
      expect(page.at_css('[href^="javascript:"]')).to be_nil
    end

    it 'has a phrase for every state the editor can report' do
      state = response.parsed_body.at_css('[data-post-editor-target="state"]')
      phrases = %w[clean dirty saving saved invalid conflict failed].map { |name| state["data-phrase-#{name}"] }

      expect(phrases).to all(be_present)
    end

    it 'points the editor at the block and upload endpoints, in the reader\'s language' do
      expect(response.body).to include('data-tinymce-blocks-url-value="/uk/management/journal_blocks"')
      expect(response.body).to include('data-tinymce-upload-url-value="/uk/management/editor_images"')
      expect(response.body).to include('aitranslation', 'post-editor')

      # The dialogs are built in JavaScript, so their wording is handed over with them.
      labels = JSON.parse(response.body[/data-tinymce-labels-value="([^"]+)"/, 1].then { CGI.unescapeHTML(it) })
      expect(labels.keys).to include(*JournalBlock::KINDS)
      expect(labels['insert']).to eq(I18n.t('management.editor.tinymce.insert', locale: :uk))
    end
  end
end
