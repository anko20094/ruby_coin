# frozen_string_literal: true

require 'rails_helper'

RSpec.describe JournalHelper do
  include_context 'when carrierwave cleanup'

  around { |example| I18n.with_locale(:en) { example.run } }

  describe '#journal_body' do
    describe 'with a cache store' do
      around do |example|
        was = Rails.cache
        Rails.cache = ActiveSupport::Cache::MemoryStore.new
        example.run
      ensure
        Rails.cache = was
      end

      let(:post) { create(:post, description_en: '<pre><code class="language-ruby">def first; end</code></pre>') }

      it 'renders a body once and serves it again from the cache' do
        helper.journal_body(post, :en)
        allow(Rouge::Lexer).to receive(:find).and_call_original

        expect(helper.journal_body(post, :en)).to include('jn-code__lang">ruby')
        expect(Rouge::Lexer).not_to have_received(:find)
      end

      it 'renders again after a deploy, since the highlighting and the embed markup are code' do
        helper.journal_body(post, :en)
        allow(HttpCaching).to receive(:release).and_return('the next deploy')
        allow(Rouge::Lexer).to receive(:find).and_call_original

        helper.journal_body(post, :en)

        expect(Rouge::Lexer).to have_received(:find).at_least(:once)
      end

      it 'lets an entry age out of the store rather than keeping it for good' do
        helper.journal_body(post, :en)
        allow(Rouge::Lexer).to receive(:find).and_call_original

        travel(described_class::BODY_TTL + 1.minute) { helper.journal_body(post, :en) }

        expect(Rouge::Lexer).to have_received(:find).at_least(:once)
      end

      it 'renders again once the body is edited' do
        helper.journal_body(post, :en)
        post.update!(description_en: '<pre><code class="language-ruby">def second; end</code></pre>')

        expect(helper.journal_body(post.reload, :en)).to include('second')
      end
    end

    it 'highlights a code block and names its language' do
      post = create(:post, description_en: '<pre><code class="language-ruby">def call; end</code></pre>')

      body = helper.journal_body(post, :en)

      expect(body).to include('jn-code__lang">ruby')
      expect(body).to include('<span class="k">def</span>')
    end

    # TinyMCE's code-sample puts the class on the <pre>, not on the <code> inside it. Reading
    # only the <code> meant a listing inserted from the toolbar was highlighted in the editor,
    # by the editor's own copy of Prism, and arrived on the page grey — the one place the
    # difference does not show up until it is published.
    it 'reads the language off the <pre> as well, which is where the toolbar puts it' do
      post = create(:post, description_en: '<pre class="language-ruby"><code>def call; end</code></pre>')

      body = helper.journal_body(post, :en)

      expect(body).to include('jn-code__lang">ruby')
      expect(body).to include('<span class="k">def</span>')
    end

    it 'accepts the other spelling of the same class' do
      post = create(:post, description_en: '<pre class="lang-ruby"><code>def call; end</code></pre>')

      expect(helper.journal_body(post, :en)).to include('jn-code__lang">ruby')
    end

    it 'leaves a code block with no language plain rather than guessing' do
      post = create(:post, description_en: '<pre>just some text</pre>')

      expect(helper.journal_body(post, :en)).not_to include('jn-code')
    end

    it 'highlights the listing the editor calls ERB / HTML, which Prism names markup' do
      post = create(:post, description_en: '<pre class="language-markup"><code>&lt;b&gt;y&lt;/b&gt;</code></pre>')

      expect(helper.journal_body(post, :en)).to include('jn-code__lang">html', '<span class="nt">')
    end

    it 'finds a lexer for every language the editor offers' do
      profiles = Rails.root.join('app', 'javascript', 'admin', 'tinymce', 'profiles.js').read
      offered = profiles[/codesample_languages:\s*\[(.*?)\]/m, 1].scan(/value:\s*"([^"]+)"/).flatten

      expect(offered).to include('ruby', 'markup')
      expect(offered.reject { |language| helper.__send__(:lexer_named, language) }).to be_empty
    end

    it 'leaves a language Rouge does not know plain' do
      post = create(:post, description_en: '<pre><code class="language-nonesuch">x</code></pre>')

      expect(helper.journal_body(post, :en)).not_to include('jn-code')
    end

    it 'renders the body of the locale it is asked for' do
      post = create(:post, description_en: '<p>English</p>', description_uk: '<p>Українською</p>')

      expect(helper.journal_body(post, :uk)).to include('Українською')
      expect(helper.journal_body(post, :uk)).not_to include('English')
    end
  end

  describe 'blocks in the body' do
    def attach(post, block)
      post.update!(description_en: %(<action-text-attachment sgid="#{block.attachable_sgid}"></action-text-attachment>))
      helper.journal_body(post, :en)
    end

    it 'highlights a code block and labels its language' do
      block = JournalBlock.create!(kind: 'code', payload: { 'language' => 'ruby', 'source' => 'def call; end' })

      body = attach(create(:post), block)

      expect(body).to include('jn-code__lang">ruby')
      expect(body).to include('<span class="k">def</span>')
    end

    it 'highlights a block whose language was typed with capitals and a stray space' do
      block = JournalBlock.create!(kind: 'code', payload: { 'language' => 'Ruby ', 'source' => 'def call; end' })

      expect(attach(create(:post), block)).to include('<span class="k">def</span>')
    end

    it 'renders a callout in the tone it was given' do
      block = JournalBlock.create!(kind: 'callout', payload: { 'tone' => 'warn', 'body' => 'This one bites.' })

      body = attach(create(:post), block)

      expect(body).to include('jn-callout--warn')
      expect(body).to include('This one bites.')
    end

    # The sanitiser strips these on the way out of Action Text, so the helper has to put them
    # back; without this the embed would render as a dead link.
    it 'puts the embed wiring back after the sanitiser removes it' do
      block = JournalBlock.create!(kind: 'embed', payload: { 'url' => 'https://x.com/a', 'caption' => 'The talk' })

      body = attach(create(:post), block)

      expect(body).to include('data-controller="embed"')
      expect(body).to include('data-embed-url-value="https://x.com/a"')
      expect(body).to include('data-action="embed#load"')
      expect(body).to include('rel="noreferrer"')
      expect(body).to include('jn-embed__caption">The talk')
    end
  end

  describe '#journal_byline' do
    it 'reads author · reading time · tags' do
      post = create(:post)
      post.tags << create(:tag, title: 'ops')

      expect(helper.journal_byline(post)).to eq("#{post.user.nickname} · 1 min · #ops")
    end

    it 'drops the tag segment when there are none' do
      post = create(:post)

      expect(helper.journal_byline(post)).to eq("#{post.user.nickname} · 1 min")
    end
  end

  describe '#journal_chip_class' do
    it 'marks only the selected chip' do
      expect(helper.journal_chip_class(active: true)).to include('is-active')
      expect(helper.journal_chip_class(active: false)).not_to include('is-active')
    end
  end
end
