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
  end
end
