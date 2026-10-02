# frozen_string_literal: true

class Post < ApplicationRecord
  LIMIT_COUNT = 3
  has_and_belongs_to_many :tags
  belongs_to :user
  extend Mobility

  # Table backend over post_translations, read and written only through Post#translations. See
  # config/initializers/mobility.rb for what is switched on and what is not.
  translates :title, :subtitle
  # The legacy bodies are still in post_translations.description (see PostTranslation), and
  # every preload of the titles would read them along with it.
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
  # What makes a body more than empty, in Ruby and in Postgres alike: one character that is not
  # whitespace. Markup counts, so an <img> alone is a body.
  BODY_CONTENT = /[^[:space:]]/
  # Words per minute for the "N min" label. Compute, never store — it goes stale on edit.
  READING_SPEED = 200
  # How long a post wears the ruby NEW badge on the journal index.
  RECENT_FOR = 14.days

  has_rich_text :description_en
  has_rich_text :description_uk

  # Searching action_text_rich_texts.body directly would match HTML tag names, so each body
  # is mirrored into a stripped column on posts and the scopes stay off the join.
  pg_search_scope :search_everywhere, against: %i[search_body_en search_body_uk],
                                      associated_against: { translations: [:title] },
                                      using: { tsearch: { prefix: true, any_word: true } },
                                      order_within_rank: 'posts.created_at DESC'
  pg_search_scope :search_by_title, associated_against: { translations: [:title] },
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

  # Post.active and Post.inactive are the enum's own scopes and carry no order: a caller that
  # lists posts says which order it wants, so a search or a count never has to unscope one.
  enum :status, { active: 0, inactive: 1 }

  scope :ordered, -> { order(created_at: :desc) }
  # Featured *and* published. Featuring is a display choice, hiding is a publication one, and
  # the second has to win.
  scope :main, -> { where(main_post: true, status: :active).ordered }
  # Most read first. Views are aggregated once and LEFT JOINed, so unread entries sort last
  # instead of disappearing (filtering the event name inside the join would make it inner).
  #
  # If the events table ever gets large enough for that to matter, the answer is a stored count
  # on posts rather than a cleverer query — not built yet for traffic the site does not have.
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
  # as a blank row; this is the posts that can be read in it. The same three conditions as
  # #translated_in? — title, subtitle, a body with anything in it — so a post is either listed
  # and openable in a language or neither. The body is the rich text, not its plain-text copy:
  # an entry that is only a picture has a body and no words.
  scope :translated_in, lambda { |locale|
    titled = Post::Translation.where(locale: locale.to_s).where.not(title: [nil, '']).where.not(subtitle: [nil, ''])
    bodied = ActionText::RichText.where(record_type: name, name: rich_text_name(locale).to_s)
                                 .where('action_text_rich_texts.body ~ ?', BODY_CONTENT.source)

    where(id: titled.select(:post_id)).where(id: bodied.select(:record_id))
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
  def self.rich_text_name(locale) = RICH_TEXT_BODIES[locale.to_sym] || :description_en

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
    translation = translations.find { |row| row.locale == locale.to_s }
    return false if translation.nil? || translation.title.blank? || translation.subtitle.blank?

    # The association reader, not the has_rich_text one: that would build an empty record. The
    # stored markup, not #to_s, which wraps every body in the Action Text layout.
    body = public_send(:"rich_text_#{self.class.rich_text_name(locale)}")&.body
    body.present? && body.to_html.match?(BODY_CONTENT)
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
