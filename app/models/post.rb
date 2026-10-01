# frozen_string_literal: true

class Post < ApplicationRecord
  require 'i18n'

  LIMIT_COUNT = 3
  has_and_belongs_to_many :tags
  belongs_to :user
  # Mobility's Table backend also defines Post#translations over these same rows (as
  # Post::Translation). This association is the one the app uses — pg_search's
  # associated_against, Posts::Translator and posts_helper all name it.
  has_many :post_translations, dependent: :destroy

  extend Mobility

  # Table backend over post_translations. See config/initializers/mobility.rb for what is
  # switched on and what is not.
  translates :title, :subtitle
  # Mobility's translation class spans the whole table, and every preload would read the legacy
  # bodies in `description` along with the title.
  Post::Translation.ignored_columns += %w[description]

  extend FriendlyId

  friendly_id :slug, use: %i[slugged finders history]
  include PgSearch::Model

  # A reader who arrives at a numbered series wants to start at the beginning. The journal
  # offered "new" and "best" and nothing else, so #001 was only reachable by paging to the end.
  ORDER_TYPES = %w[new oldest best].freeze

  # The body lives in Action Text, one named rich text per locale. post_translations.description
  # is left in place as a dormant backup of the pre-Action-Text bodies and is no longer read.
  RICH_TEXT_BODIES = { en: :description_en, uk: :description_uk }.freeze
  # Words per minute for the "N min" label. Compute, never store — it goes stale on edit.
  READING_SPEED = 200
  # How long a post wears the ruby NEW badge on the journal index.
  RECENT_FOR = 14.days

  has_rich_text :description_en
  has_rich_text :description_uk

  # Searching action_text_rich_texts.body directly would match HTML tag names, so each body
  # is mirrored into a stripped column on posts and the scopes stay off the join.
  pg_search_scope :search_everywhere, against: %i[search_body_en search_body_uk],
                                      associated_against: { post_translations: [:title] },
                                      using: { tsearch: { prefix: true, any_word: true } },
                                      order_within_rank: 'posts.created_at DESC'
  pg_search_scope :search_by_title, associated_against: { post_translations: [:title] },
                                    using: { tsearch: { prefix: true, any_word: true } },
                                    order_within_rank: 'posts.created_at DESC'
  pg_search_scope :search_by_description, against: %i[search_body_en search_body_uk],
                                          using: { tsearch: { prefix: true, any_word: true } },
                                          order_within_rank: 'posts.created_at DESC'

  mount_uploader :photo, PhotoUploader
  before_save :deactivate_previous_main_post, if: -> { main_post? && will_save_change_to_main_post? }
  before_save :mirror_search_bodies
  before_create :assign_entry_number

  validates :title, presence: true
  validates :subtitle, presence: true
  validate :description_present
  validate :slug_available, if: :will_save_change_to_slug?
  validates :photo, presence: true
  validates :main_post, inclusion: { in: [true, false] }

  enum :status, { active: 0, inactive: 1 }

  scope :ordered, -> { order(created_at: :desc) }
  # Featured *and* published. Featuring is a display choice, hiding is a publication one, and
  # the second has to win: a post switched to inactive was still being shown on the home page
  # because this scope only asked the first question.
  scope :main, -> { where(main_post: true, status: :active).ordered }
  scope :active, -> { where(status: :active).ordered }
  scope :inactive, -> { where(status: :inactive).ordered }
  # Most read first.
  #
  # Two things were wrong with this. It said LEFT JOIN and then filtered on
  # `ahoy_events.name`, which turns the outer join back into an inner one — so "best" listed
  # only posts somebody had already opened, and a new entry could not appear there until it
  # had been read somewhere else first. And it joined every event row to every post before
  # grouping: 622 ms at 100k events, measured.
  #
  # Counting views means reading the view rows, so the sequential scan does not go away. But
  # aggregating them once and joining the result costs half as much — 314 ms on the same data —
  # and the LEFT JOIN puts the unread entries at the end of the list instead of hiding them.
  #
  # If the events table ever gets large enough for that to matter, the answer is a stored count
  # on posts rather than a cleverer query; it is written down in redesign_plan.md rather than
  # built for traffic the site does not have.
  scope :best, lambda {
    counts = Ahoy::Event.where(name: 'Viewed Post')
                        .select(Arel.sql("(properties->>'post_id')::bigint AS post_id, COUNT(*) AS views_count"))
                        .group(Arel.sql("(properties->>'post_id')::bigint"))

    active
      .joins("LEFT JOIN (#{counts.to_sql}) view_counts ON view_counts.post_id = posts.id")
      .select('posts.*, COALESCE(view_counts.views_count, 0) AS views_count')
      .reorder(Arel.sql('COALESCE(view_counts.views_count, 0) DESC, posts.created_at DESC'))
  }
  scope :oldest, -> { where(status: :active).order(created_at: :asc) }
  # Mobility's fallbacks are off, so a post with no title or body in a language would list there
  # as a blank row; this is the posts that can be read in it.
  scope :translated_in, lambda { |locale|
    titled = PostTranslation.where(locale: locale.to_s).where.not(title: [nil, '']).where.not(subtitle: [nil, ''])

    where(id: titled.select(:post_id)).where.not("search_body_#{locale}" => [nil, ''])
  }

  # The entry either side of this one, by the series number the site prints. Nothing linked
  # posts to each other before: the only way out of an entry was back to the index or a
  # tag-similarity row, so a series could not be read as a series.
  scope :before, ->(post) { active.where(entry_number: ...post.entry_number).reorder(entry_number: :desc) }
  scope :after, ->(post) { active.where('entry_number > ?', post.entry_number).reorder(entry_number: :asc) }

  # Overlap is counted in a subquery: a WHERE on tags would eager-load only the matched tags onto each card.
  scope :similar_posts, lambda { |current_post|
    overlap = Post.joins(:tags).where(tags: { id: current_post.tag_ids })
                  .group('posts.id').select('posts.id AS post_id, COUNT(*) AS tag_count')

    active
      .where.not(id: current_post.id)
      .joins("INNER JOIN (#{overlap.to_sql}) overlap ON overlap.post_id = posts.id")
      .reorder(Arel.sql('overlap.tag_count DESC, posts.created_at DESC'))
      .limit(LIMIT_COUNT)
  }

  # A slug counts as taken while any other post holds it now or held it before: FriendlyId
  # redirects an old address, so reusing one would silently steal it.
  def self.slug_taken?(slug, except: nil)
    where.not(id: except).exists?(slug:) ||
      FriendlyId::Slug.where(sluggable_type: name, slug:).where.not(sluggable_id: except).exists?
  end

  # `base`, or the first of base-2, base-3... that nobody holds.
  def self.unused_slug(base)
    return if base.blank?

    (1..).lazy.map { |number| number == 1 ? base : "#{base}-#{number}" }.find { |slug| !slug_taken?(slug) }
  end

  # The body for one locale, as an ActionText::RichText. Reading and writing `description`
  # without a locale means the current one, which keeps the admin form's param shape
  # (post[description] for the locale being edited, post[description_localizations] for the
  # rest) working exactly as it did before the body moved out of Globalize.
  def rich_body(locale = I18n.locale)
    public_send(RICH_TEXT_BODIES[locale.to_sym] || :description_en)
  end

  def description
    rich_body
  end

  def description=(value)
    public_send(:"#{RICH_TEXT_BODIES[I18n.locale] || :description_en}=", value)
  end

  def plain_body(locale = I18n.locale)
    self[:"search_body_#{RICH_TEXT_BODIES.key?(locale.to_sym) ? locale : :en}"].to_s
  end

  def reading_minutes(locale = I18n.locale)
    [(plain_body(locale).split.size.to_f / READING_SPEED).ceil, 1].max
  end

  def recent?
    created_at.present? && created_at > RECENT_FOR.ago
  end

  # Which locales this post is actually finished in. "Finished" means all three parts are
  # there — title, subtitle and body — because a post missing any one of them cannot be read
  # in that language. This is what the admin's language-pair indicator shows, and the most
  # common editing question it answers: what is missing a translation.
  def translated_locales
    I18n.available_locales.select { |locale| translated_in?(locale) }
  end

  def translated_in?(locale)
    translation = post_translations.find { |row| row.locale == locale.to_s }
    return false if translation.nil? || translation.title.blank? || translation.subtitle.blank?

    # The association reader, not the has_rich_text one: that would build an empty record.
    public_send(:"rich_text_#{RICH_TEXT_BODIES[locale.to_sym] || :description_en}")&.body.present?
  end

  # #042 — a stored series number, printed the same way everywhere.
  def entry_label
    format('#%03d', entry_number) if entry_number.present?
  end

  private

  def description_present
    return if rich_body.body.present?

    errors.add(:description, :blank)
  end

  # Continues from the highest number in the table rather than the row count, so a gap in the
  # middle of the series stays a gap. Deleting the newest post does free its number for the
  # next one — the number is a display label, not an identity, and the unique index is what
  # keeps two live posts from sharing one.
  def assign_entry_number
    self.entry_number ||= (Post.maximum(:entry_number) || 0) + 1
  end

  # pg_search reads these, so they must track the rich text on every save. The rich text is
  # still unsaved at this point, but its body is already assigned in memory.
  def mirror_search_bodies
    RICH_TEXT_BODIES.each do |locale, field|
      rich_text = public_send(:"rich_text_#{field}")
      self[:"search_body_#{locale}"] = rich_text&.body&.to_plain_text
    end
  end

  def slug_available
    errors.add(:slug, :taken) if slug.present? && self.class.slug_taken?(slug, except: id)
  end

  # Unvalidated, since the old one may be unfinished in this locale; saved rather than
  # update_all so its lock_version moves and an editor who has it open is told.
  def deactivate_previous_main_post
    Post.where(main_post: true).where.not(id:).find_each do |previous|
      previous.main_post = false
      previous.save!(validate: false)
    end
  end
end
