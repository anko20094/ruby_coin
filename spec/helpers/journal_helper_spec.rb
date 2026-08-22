# frozen_string_literal: true

require 'rails_helper'

RSpec.describe JournalHelper do
  include_context 'when carrierwave cleanup'

  around { |example| I18n.with_locale(:en) { example.run } }

  describe '#journal_body' do
    it 'highlights a code block and names its language' do
      post = create(:post, description_en: '<pre><code class="language-ruby">def call; end</code></pre>')

      body = helper.journal_body(post, :en)

      expect(body).to include('jn-code__lang">ruby')
      expect(body).to include('<span class="k">def</span>')
    end

    it 'leaves a code block with no language plain rather than guessing' do
      post = create(:post, description_en: '<pre>just some text</pre>')

      expect(helper.journal_body(post, :en)).not_to include('jn-code')
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
