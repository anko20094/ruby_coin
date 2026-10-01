# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Post do
  include_context 'when carrierwave cleanup'

  let(:post) { create(:post, status: 'active') }

  describe 'associations' do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to have_and_belong_to_many(:tags) }
  end

  describe 'enums' do
    it { is_expected.to define_enum_for(:status).with_values(active: 0, inactive: 1) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_presence_of(:subtitle) }
    it { is_expected.to validate_presence_of(:description) }
    it { is_expected.to validate_presence_of(:photo) }
  end

  describe 'photo uploader' do
    it 'has a photo uploader mounted' do
      expect(post.photo).to be_a(PhotoUploader)
    end

    it 'uploads a photo successfully' do
      image_path = Rails.root.join('spec', 'fixtures', 'files', 'test_image.png')
      post.update(photo: fixture_file_upload(image_path, 'image/png'))
      expect(post.photo).to be_present
    end
  end

  describe "updating post's photo" do
    it 'updates the cached profile image for post' do
      expect { post.update(photo: fixture_file_upload('thumb_icon.png', 'image/png')) }
        .to(change { post.reload.photo })
    end
  end

  describe 'similar_posts' do
    let(:similar_tag) { create(:tag) }
    let(:post) { create(:post, :active, tags: [similar_tag]) }

    context 'when similar_posts is active' do
      let(:similar_post) { create(:post, :active, tags: [similar_tag]) }

      it 'returns active posts with similar tags' do
        expect(described_class.similar_posts(post)).to include(similar_post)
      end
    end

    context 'when similar_posts is NOT active' do
      let(:similar_post) { create(:post, :inactive, tags: [similar_tag]) }

      it 'returns active posts with similar tags' do
        expect(described_class.similar_posts(post)).not_to include(similar_post)
      end
    end

    context 'when no similar posts' do
      it 'excludes the given post from the result' do
        expect(described_class.similar_posts(post)).not_to include(post)
      end
    end

    context 'when lots of similar posts' do
      let(:similar_posts) { Array.new(Post::LIMIT_COUNT + 1) { create(:post, :active, tags: [similar_tag]) } }

      it 'limits the result to LIMIT_COUNT' do
        similar_posts.each { |p| p.tags << similar_tag }
        expect(described_class.similar_posts(post).count).to eq(Post::LIMIT_COUNT)
      end
    end

    context 'when the candidates share different numbers of tags' do
      let(:tags) { create_list(:tag, 4) }
      let(:post) { create(:post, :active, tags: tags) }
      let!(:one_shared) { create(:post, :active, tags: tags.first(1), created_at: 1.day.ago) }
      let!(:three_shared) { create(:post, :active, tags: tags.first(3), created_at: 3.days.ago) }
      let!(:two_shared_older) { create(:post, :active, tags: tags.last(2), created_at: 5.days.ago) }
      let!(:two_shared_newer) { create(:post, :active, tags: tags.first(2), created_at: 2.days.ago) }

      it 'puts the most tags in common first, and the newest first among equals' do
        expect(described_class.similar_posts(post)).to eq([three_shared, two_shared_newer, two_shared_older])
      end
    end

    context 'when the only thing in common is the last of many tags' do
      let(:tags) { create_list(:tag, 5) }
      let(:post) { create(:post, :active, tags: tags) }
      let!(:last_shared) { create(:post, :active, tags: tags.last(1)) }

      it 'still finds the post' do
        expect(described_class.similar_posts(post)).to eq([last_shared])
      end
    end

    context 'when the cards are drawn' do
      let(:tags) { create_list(:tag, 3) }
      let!(:post) { create(:post, :active, tags: tags.first(1)) }

      before { create(:post, :active, tags: tags) }

      it 'carries every tag of a related post, not only the one it was matched on' do
        related = described_class.similar_posts(post).includes(:tags, :user, :translations).to_a

        expect(related.first.tags.map(&:id)).to match_array(tags.map(&:id))
      end

      it 'reads the posts in one query' do
        statements = []
        collect = ->(*, payload) { statements << payload[:sql] unless payload[:name] == 'SCHEMA' }

        ActiveSupport::Notifications.subscribed(collect, 'sql.active_record') do
          described_class.similar_posts(post).includes(:tags, :user, :translations).to_a
        end

        expect(statements.grep(/FROM "posts"/).size).to eq(1)
      end
    end
  end

  describe '.ordered' do
    it 'orders posts by created_at in descending order' do
      post1 = create(:post, created_at: Time.current)
      post2 = create(:post, created_at: 1.hour.ago)
      post3 = create(:post, created_at: 2.hours.ago)

      expect(described_class.ordered).to eq([post1, post2, post3])
    end
  end

  # Featuring is a display choice and hiding is a publication one, and the second wins: the
  # home page must never show an entry the author has switched off.
  describe '.main' do
    it 'returns a post that is featured and published' do
      featured = create(:post, :main_post)

      expect(described_class.main).to contain_exactly(featured)
    end

    it 'leaves out a featured post that is hidden' do
      create(:post, :main_post, :inactive)

      expect(described_class.main).to be_empty
    end

    it 'puts the newest featured post first' do
      older = create(:post, created_at: 2.days.ago)
      newer = create(:post, created_at: 1.day.ago)
      described_class.where(id: [older.id, newer.id]).update_all(main_post: true)

      expect(described_class.main.first).to eq(newer)
    end
  end

  describe 'featuring a post' do
    it 'takes the flag off the post that had it' do
      first = create(:post, :main_post)
      second = create(:post, :main_post)

      expect(first.reload.main_post).to be(false)
      expect(second.reload.main_post).to be(true)
    end

    it 'does so when the previous one is unfinished in the current locale' do
      previous = I18n.with_locale(:en) { create(:post, :main_post) }
      current = I18n.with_locale(:uk) { create(:post, :main_post) }

      expect(described_class.where(main_post: true)).to contain_exactly(current)
      expect(I18n.with_locale(:uk) { previous.reload.valid? }).to be(false)
    end

    it 'repairs a pair that is already featured' do
      pair = create_list(:post, 2)
      described_class.where(id: pair.map(&:id)).update_all(main_post: true)
      current = create(:post, :main_post)

      expect(described_class.where(main_post: true)).to contain_exactly(current)
    end

    it 'moves the version of the post it demotes, so an editor who has it open is told' do
      previous = create(:post, :main_post)

      expect { create(:post, :main_post) }.to change { previous.reload.lock_version }.by(1)
    end

    it 'leaves every other post alone when it is not featured' do
      featured = create(:post, :main_post)

      expect { create(:post) }.not_to(change { featured.reload.lock_version })
      expect(featured.reload.main_post).to be(true)
    end
  end

  # The slug is the canonical address, and FriendlyId answers an old one with a redirect.
  describe 'slugs' do
    let!(:holder) { create(:post, slug: 'first-address') }

    it 'refuses a slug another post holds' do
      other = build(:post, slug: 'first-address')

      expect(other).not_to be_valid
      expect(other.errors.added?(:slug, :taken)).to be(true)
    end

    it 'refuses a slug another post used to hold, because that address redirects to it' do
      holder.update!(slug: 'second-address')

      expect(build(:post, slug: 'first-address')).not_to be_valid
    end

    it 'lets a post go back to a slug it used before' do
      holder.update!(slug: 'second-address')

      expect(holder.update(slug: 'first-address')).to be(true)
    end

    it 'does not take a post to be in conflict with itself' do
      expect(holder.reload).to be_valid
    end

    it 'has no opinion on a post that has no slug yet' do
      expect(build(:post, slug: nil)).to be_valid
    end

    describe '.unused_slug' do
      it 'is the base itself while nobody holds it' do
        expect(described_class.unused_slug('a-new-title')).to eq('a-new-title')
      end

      it 'counts up past every holder, current or former' do
        create(:post, slug: 'a-title')
        create(:post, slug: 'a-title-2')
        former = create(:post, slug: 'a-title-3')
        former.update!(slug: 'renamed')

        expect(described_class.unused_slug('a-title')).to eq('a-title-4')
      end

      it 'is nil for a blank base' do
        expect(described_class.unused_slug('')).to be_nil
      end
    end
  end

  describe 'Action Text bodies' do
    let(:post) { create(:post, description_en: '<p>English body</p>', description_uk: '<p>Українське тіло</p>') }

    it 'keeps one body per locale' do
      expect(post.rich_body(:en).body.to_plain_text.strip).to eq('English body')
      expect(post.rich_body(:uk).body.to_plain_text.strip).to eq('Українське тіло')
    end

    it 'reads and writes the current locale through #description' do
      I18n.with_locale(:en) { expect(post.description.body.to_plain_text.strip).to eq('English body') }
      I18n.with_locale(:uk) { expect(post.description.body.to_plain_text.strip).to eq('Українське тіло') }
    end

    it 'mirrors each body into a stripped column so pg_search never sees HTML' do
      expect(post.plain_body(:en).strip).to eq('English body')
      expect(post.plain_body(:en)).not_to include('<p>')
    end

    it 'keeps the mirror in step with an edit' do
      post.update!(description_en: '<p>Rewritten entirely</p>')

      expect(post.reload.plain_body(:en).strip).to eq('Rewritten entirely')
      expect(described_class.search_by_description('Rewritten')).to include(post)
    end

    context 'when the body holds journal blocks' do
      let(:code) { JournalBlock.create!(kind: 'code', payload: { 'source' => 'def uniquecodetoken; end' }) }
      let(:callout) { JournalBlock.create!(kind: 'callout', payload: { 'body' => 'uniquecallouttoken bites' }) }
      let(:embed) do
        JournalBlock.create!(kind: 'embed', payload: { 'url' => 'https://x.com/a', 'caption' => 'uniquecaptiontoken' })
      end
      let(:body) do
        blocks = [code, callout, embed].map do |block|
          %(<action-text-attachment sgid="#{block.attachable_sgid}"></action-text-attachment>)
        end

        "<p>intro words here</p>#{blocks.join}"
      end

      before { post.update!(description_en: body) }

      it 'can be searched for what is inside a block' do
        %w[uniquecodetoken uniquecallouttoken uniquecaptiontoken].each do |token|
          expect(described_class.search_everywhere(token)).to include(post)
        end
      end

      it 'counts what is inside a block towards the reading time' do
        expect(post.plain_body(:en).split.size).to be > 3
      end

      it 'keeps the words around a block apart from it' do
        expect(post.plain_body(:en)).to include('intro words here')
        expect(post.plain_body(:en)).not_to include('here def')
      end
    end
  end

  describe 'entry numbers' do
    it 'numbers new posts from the highest number, so a gap in the middle stays a gap' do
      first = create(:post)
      second = create(:post)
      third = create(:post)
      second.destroy

      expect(create(:post).entry_number).to eq(third.entry_number + 1)
      expect(first.entry_number).to eq(third.entry_number - 2)
    end

    it 'prints the number three digits wide' do
      expect(create(:post, entry_number: 42).entry_label).to eq('#042')
    end

    it 'has no label when it has no number' do
      expect(build(:post, entry_number: nil).entry_label).to be_nil
    end
  end

  describe '#reading_minutes' do
    it 'counts words at READING_SPEED, never below one minute' do
      post = create(:post, description_en: "<p>#{'word ' * 401}</p>")

      expect(post.reading_minutes(:en)).to eq(3)
      expect(create(:post, description_en: '<p>one</p>').reading_minutes(:en)).to eq(1)
    end
  end

  describe '#recent?' do
    it 'is true inside RECENT_FOR and false outside it' do
      expect(create(:post)).to be_recent
      expect(create(:post, created_at: (Post::RECENT_FOR + 1.day).ago)).not_to be_recent
    end
  end

  # Mobility replaced Globalize in W6a on the same table. Nothing in the suite noticed, which
  # is the point — these pin the two behaviours a future change could break quietly.
  describe 'translated title and subtitle' do
    let(:post) { create(:post) }

    # Saving in a locale needs that locale's title, subtitle and body — the presence
    # validations read the current locale, which is how the editorial rule is enforced.
    it 'keeps one row per locale, not one per write' do
      I18n.with_locale(:en) { post.update!(title: 'English title', subtitle: 'English lede') }
      I18n.with_locale(:uk) { post.update!(title: 'Український заголовок', subtitle: 'Український лід') }

      expect(post.reload.post_translations.pluck(:locale).sort).to eq(%w[en uk])
      expect(post.translations.count).to eq(post.post_translations.count)
    end

    it 'does not read the legacy body column on a preload, though it stays in the table' do
      post.post_translations.update_all(description: '<p>the body from before Action Text</p>')

      loaded = described_class.includes(:translations).find(post.id).translations.first

      expect(loaded.has_attribute?(:description)).to be(false)
      expect(PostTranslation.find_by(post_id: post.id).description).to include('before Action Text')
    end

    it 'reads each locale back on its own' do
      I18n.with_locale(:en) { post.update!(title: 'English title', subtitle: 'English lede') }
      I18n.with_locale(:uk) { post.update!(title: 'Український заголовок', subtitle: 'Український лід') }
      post.reload

      expect(I18n.with_locale(:en) { post.title }).to eq('English title')
      expect(I18n.with_locale(:uk) { post.title }).to eq('Український заголовок')
    end

    # Deliberate: an untranslated post has to render empty so the gap is visible, rather than
    # quietly showing the other language.
    it 'does not fall back to another locale' do
      post.post_translations.where(locale: 'en').delete_all

      expect(I18n.with_locale(:en) { post.reload.title }).to be_nil
    end

    it 'is still searchable through the association pg_search names' do
      I18n.with_locale(:uk) { post.update!(title: 'Мобільність', subtitle: 'Підзаголовок') }

      expect(described_class.search_by_title('Мобільність')).to include(post)
    end
  end

  describe '#translated_locales' do
    let(:post) { create(:post) }

    it 'counts a locale as translated only when title, subtitle and body are all there' do
      I18n.with_locale(:en) { post.update!(title: 'Title', subtitle: 'Lede') }
      I18n.with_locale(:uk) { post.update!(title: 'Заголовок', subtitle: 'Лід') }

      expect(post.reload.translated_locales).to contain_exactly(:en, :uk)
    end

    it 'drops a locale that is missing its subtitle' do
      I18n.with_locale(:en) { post.update!(title: 'Title', subtitle: 'Lede') }
      I18n.with_locale(:uk) { post.update!(title: 'Заголовок', subtitle: 'Лід') }
      post.post_translations.find_by(locale: 'en').update!(subtitle: nil)

      expect(post.reload.translated_locales).to eq([:uk])
    end

    it 'drops a locale that is missing its body' do
      I18n.with_locale(:en) { post.update!(title: 'Title', subtitle: 'Lede') }
      I18n.with_locale(:uk) { post.update!(title: 'Заголовок', subtitle: 'Лід') }
      post.rich_text_description_en.destroy

      expect(post.reload.translated_locales).to eq([:uk])
    end

    # It reads the association, not the has_rich_text accessor, which would build a row.
    it 'does not create an empty rich text while checking' do
      post.rich_text_description_en.destroy

      expect { post.reload.translated_locales }.not_to change(ActionText::RichText, :count)
    end
  end

  # "Best" said LEFT JOIN and then filtered on the joined table, which makes it an inner join:
  # the list showed only entries somebody had already opened, so a new one could never appear
  # in it. Counting views should not decide whether a post exists.
  describe '.best' do
    include_context 'when carrierwave cleanup'

    let!(:read) { create(:post, status: 'active') }
    let!(:unread) { create(:post, status: 'active') }
    let!(:hidden) { create(:post, status: 'inactive') }

    before do
      2.times { create(:ahoy_event, name: 'Viewed Post', properties: { post_id: read.id }) }
      create(:ahoy_event, name: 'Viewed Case', properties: { case_id: read.id })
    end

    it 'puts the most-read first' do
      expect(described_class.best.first).to eq(read)
    end

    it 'still lists an entry nobody has opened' do
      expect(described_class.best).to include(unread)
    end

    it 'never lists a hidden one' do
      expect(described_class.best).not_to include(hidden)
    end

    it 'counts post views only' do
      expect(described_class.best.first.attributes['views_count']).to eq(2)
    end

    it 'can be counted for the pager' do
      expect(described_class.best.except(:select, :order).distinct.count(:id)).to eq(2)
    end
  end

  describe '.translated_in' do
    let(:full) do
      I18n.with_locale(:en) { create(:post, title: 'Both ways') }.tap do |post|
        I18n.with_locale(:uk) { post.update!(title: 'Обидва', subtitle: 'Підзаголовок') }
      end
    end
    let(:no_body_in_uk) { I18n.with_locale(:en) { create(:post, title: 'English body only') } }

    it 'needs a title, a subtitle and a stored body in the language' do
      I18n.with_locale(:uk) { no_body_in_uk.update!(title: 'Є лише заголовок', subtitle: 'Є підзаголовок') }
      no_body_in_uk.update_columns(search_body_uk: nil)

      expect(described_class.translated_in(:uk)).to include(full)
      expect(described_class.translated_in(:uk)).not_to include(no_body_in_uk)
      expect(described_class.translated_in(:en)).to include(full, no_body_in_uk)
    end
  end
end
