# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Cases::Topics do
  include_context 'when carrierwave cleanup'

  around { |example| I18n.with_locale(:en) { example.run } }

  let(:site) { Case.new(slug: 'site', stack: ['Rails 8.1 · Ruby 3.4', 'PostgreSQL 17', 'Hotwire · Stimulus']) }
  let(:bot) { Case.new(slug: 'bot', stack: ['Rails 8.1', 'PostgreSQL 18', 'Sidekiq · Redis']) }
  let(:render) { Case.new(slug: 'render', stack: ['Rails 8.1', 'ImageMagick 7']) }
  let(:topics) { described_class.new([site, bot, render]) }

  describe '#keys_for' do
    it 'reads tag-shaped keys out of the stack, with PostgreSQL as postgres' do
      expect(topics.keys_for(site)).to include('postgres', 'hotwire', 'stimulus', 'ruby')
    end

    it 'drops what every case has, since it tells them apart from nothing' do
      expect(topics.keys_for(site)).not_to include('rails')
    end
  end

  describe '#posts_for' do
    let!(:on_hotwire) { create(:post, status: 'active', tags: [create(:tag, title: 'Hotwire')], title: 'Hotwire') }
    let!(:on_both) do
      create(:post, status: 'active', tags: [create(:tag, title: 'postgres'), on_hotwire.tags.first], title: 'Both')
    end

    before { create(:post, status: 'active', tags: [create(:tag, title: 'rails')], title: 'Only rails') }

    it 'lists the entries on the stack, the closest first, matching tags case-insensitively' do
      expect(topics.posts_for(site)).to eq([on_both, on_hotwire])
    end

    it 'is empty for a case nothing in the journal is about' do
      expect(topics.posts_for(render)).to be_empty
    end

    it 'leaves out what the language cannot read' do
      expect(topics.posts_for(site, locale: :uk)).to be_empty
    end

    it 'leaves out an entry another case matches more closely, as the entry itself does' do
      on_bot = create(:post, status: 'active', title: 'Queues',
                             tags: [create(:tag, title: 'sidekiq'), on_both.tags.find_by(title: 'postgres')])

      expect(topics.posts_for(bot)).to eq([on_bot])
      expect(topics.posts_for(site)).not_to include(on_bot)
    end

    it 'lists an entry under no case when its overlap is shared too widely, as #cases_for does' do
      wide = described_class.new([site, bot, Case.new(slug: 'third', stack: ['PostgreSQL']), render])
      only_postgres = create(:post, status: 'active', title: 'Indexes', tags: [on_both.tags.find_by(title: 'postgres')])

      expect(wide.cases_for(only_postgres)).to be_empty
      expect([site, bot].flat_map { |kase| wide.posts_for(kase).to_a }).not_to include(only_postgres)
    end
  end

  describe '#shared_tags and #lead_tag' do
    let(:hotwire) { Tag.new(title: 'Hotwire') }
    let(:postgres) { Tag.new(title: 'postgres') }
    let(:posts) do
      [build(:post, tags: [postgres, Tag.new(title: 'rails')]), build(:post, tags: [hotwire, postgres])]
    end

    it 'names the tags of an entry that tie it to the case, and not the rest' do
      expect(topics.shared_tags(posts.first, site)).to eq([postgres])
    end

    it 'leads with the tag most of the entries share' do
      expect(topics.lead_tag(site, posts)).to eq(postgres)
    end

    it 'breaks a tie by title, and has nothing to lead with when nothing is shared' do
      expect(topics.lead_tag(site, [build(:post, tags: [hotwire, postgres])])).to eq(hotwire)
      expect(topics.lead_tag(render, posts)).to be_nil
    end
  end

  describe '#cases_for' do
    def post_tagged(*titles) = build(:post, tags: titles.map { |title| Tag.new(title:) })

    it 'names the case the tags point at' do
      expect(topics.cases_for(post_tagged('hotwire', 'rails'))).to eq([site])
    end

    it 'names both when two share the best overlap' do
      expect(topics.cases_for(post_tagged('postgres'))).to eq([site, bot])
    end

    it 'names none when the only common ground is what every case has' do
      expect(topics.cases_for(post_tagged('rails'))).to be_empty
    end

    it 'names none when the overlap is shared too widely to mean anything' do
      wide = described_class.new([site, bot, Case.new(slug: 'third', stack: ['PostgreSQL']), render])

      expect(wide.cases_for(post_tagged('postgres'))).to be_empty
    end
  end
end
