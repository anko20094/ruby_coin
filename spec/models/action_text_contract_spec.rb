# frozen_string_literal: true

require 'rails_helper'

# What the editor can make, and what the page keeps.
#
# These two lists have to be the same list. An editor writes a table, sees it, saves, and the
# page comes back without it — that is worse than a toolbar with no table button, because the
# work is gone and nothing said so. It is how a paragraph indent and a centred image both
# ended up shipping broken: `padding-left` and `<details>` are stripped on render, and only
# the author ever found out.
#
# Every sample below is real TinyMCE output. Anything the toolbar or the Insert menu can
# produce belongs here; anything that cannot survive belongs out of the configuration, and
# both halves are named in app/javascript/admin/tinymce/profiles.js.
describe 'the Action Text contract' do # rubocop:disable RSpec/DescribeClass
  # Nokogiri re-serialises, which puts newlines inside a <tr> and a nested <ul>. What is being
  # asserted is which tags and attributes survive, not the whitespace between them.
  def sanitized(html)
    clean = ActionText::ContentHelper.sanitizer.sanitize(
      html,
      tags: ActionText::ContentHelper.allowed_tags,
      attributes: ActionText::ContentHelper.allowed_attributes
    )

    clean.to_s.gsub(/\s*\n\s*/, '')
  end

  # rubocop:disable-next Layout/LineLength,Lint/ConstantDefinitionInBlock,RSpec/LeakyConstantDeclaration
  SURVIVES = {
    'bold, italic and inline code' => '<p><strong>b</strong> <em>i</em> <code>c</code></p>',
    'underline and strikethrough' => '<p><u>u</u> <s>s</s></p>',
    'the three heading levels' => '<h2>a</h2><h3>b</h3><h4>c</h4>',
    'a blockquote' => '<blockquote><p>q</p></blockquote>',
    'a nested list' => '<ul><li>a<ul><li>b</li></ul></li></ul>',
    'a numbered list' => '<ol><li>a</li></ol>',
    'a link, including one opening in a new tab' => '<p><a href="/x" target="_blank" rel="noopener">l</a></p>',
    'an anchor' => '<p><a id="here"></a></p>',
    'a horizontal rule' => '<hr>',
    'alignment, which is written as a class' => '<p class="align-center">c</p>',
    'an image with the size attributes that stop it jumping' => '<p><img src="/a.jpg" alt="" width="278" height="371"></p>',
    'a table with header cells' => '<table><tbody><tr><td>a</td><th scope="col">b</th></tr></tbody></table>',
    'a code sample' => '<pre class="language-ruby"><code>puts 1</code></pre>',
    'a right-to-left paragraph' => '<p dir="rtl">r</p>',
    'a figure with a caption' => '<figure><img src="/a.jpg" alt=""><figcaption>c</figcaption></figure>'
  }.freeze

  SURVIVES.each do |what, html|
    it "keeps #{what}" do
      expect(sanitized(html)).to eq(html)
    end
  end

  # The other half of the contract: these are stripped, which is exactly why the plugins and
  # toolbar items that make them are not configured. If one of these ever starts surviving,
  # the button can come back.
  {
    'an inline style, which is how TinyMCE writes an indent' => ['<p style="padding-left: 40px;">i</p>', 'style'],
    'a list style, which is how advlist writes a lettered list' =>
      ['<ol style="list-style-type: lower-alpha;"><li>a</li></ol>', 'style'],
    'a font size or a colour' => ['<p><span style="font-size: 18pt; color: #e03e2d;">x</span></p>', 'style'],
    'an underline written as a style, which is what TinyMCE does unless told to write <u>' =>
      ['<p><span style="text-decoration: underline;">u</span></p>', 'style'],
    'a <details> accordion' => ['<details><summary>s</summary><p>b</p></details>', 'details'],
    'an embedded <video>' => ['<p><video controls src="/v.mp4"></video></p>', 'video'],
    'a bare <iframe>' => ['<iframe src="https://x"></iframe>', 'iframe']
  }.each do |what, (html, needle)|
    it "strips #{what}, so nothing offers it" do
      expect(sanitized(html)).not_to include(needle)
    end
  end

  # The configuration is JavaScript, so it is read as text, as tinymce_assets_spec does.
  describe 'what the post editor offers' do
    let(:source) { Rails.root.join('app', 'javascript', 'admin', 'tinymce', 'profiles.js').read }
    let(:post_profile) { source[/export const postSettings = .*?\n\}\)\n/m] }

    def quoted(text) = text.scan(/"([^"]+)"/).flatten

    it 'loads none of the plugins whose output is stripped' do
      plugins = quoted(post_profile[/plugins:\s*\[(.*?)\]/m, 1])

      expect(plugins).to include('lists', 'table', 'codesample')
      expect(plugins & %w[accordion advlist media pagebreak]).to be_empty
    end

    it 'puts nothing that writes an inline style in a menu or on the toolbar' do
      menu = post_profile[/items:\s*"([^"]+)"/, 1].split
      toolbar = quoted(post_profile[/toolbar:\s*\[(.*?)\]\.join/m, 1]).flat_map(&:split)

      expect(menu & toolbar).to include('bold')
      styled = %w[fontfamily fontsize forecolor backcolor lineheight styles indent outdent]

      expect((menu + toolbar) & styled).to be_empty
    end

    it 'writes underline as <u>' do
      expect(post_profile).to include('...INLINE_FORMATS')
      expect(source).to include('INLINE_FORMATS = { underline: { inline: "u"')
    end

    it 'takes the case editor\'s elements from the server, where the sanitiser list is' do
      expect(source).to include('valid_elements: validElements')
    end
  end

  # Journal blocks are the exception that proves it: Action Text adds its own attachment tag
  # to the allow list at render time, which the bare sanitiser above does not know about.
  it 'keeps a journal block through a real save and render' do
    block = JournalBlock.create!(kind: 'code', payload: { 'language' => 'ruby', 'source' => 'puts 1' })
    post = create(:post)
    attachment = %(<action-text-attachment sgid="#{block.attachable_sgid}"></action-text-attachment>)
    post.update!(description_en: "<p>a</p>#{attachment}")

    expect(post.reload.description_en.body.to_html).to include('action-text-attachment')
    rendered = ApplicationController.renderer.render(inline: '<%= post.description_en %>', locals: { post: post })
    expect(rendered).to include('puts')
  end
end
