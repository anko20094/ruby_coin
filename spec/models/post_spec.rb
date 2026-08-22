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
  end

  describe '.ordered' do
    it 'orders posts by created_at in descending order' do
      post1 = create(:post, created_at: Time.current)
      post2 = create(:post, created_at: 1.hour.ago)
      post3 = create(:post, created_at: 2.hours.ago)

      expect(described_class.ordered).to eq([post1, post2, post3])
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
end
