# frozen_string_literal: true

class Post < ApplicationRecord
  require 'i18n'

  LIMIT_COUNT = 3
  has_and_belongs_to_many :tags
  belongs_to :user
  # Mobility's Table backend also defines Post#translations over these same rows (as
  # Post::Translation). This association is the one the app uses — pg_search's
  # associated_against, Posts::Translator and posts_helper all name it — which is what let the
  # Globalize swap leave every one of them untouched.
  has_many :post_translations, dependent: :destroy

  extend Mobility

  # Table backend, on the table Globalize left: post_translations. See
  # config/initializers/mobility.rb for what is switched on and what is not.
  translates :title, :subtitle

  extend FriendlyId

  friendly_id :slug, use: %i[slugged finders history]
  include PgSearch::Model

  # A reader who arrives at a numbered series wants to start at the beginning. The journal
  # offered "new" and "best" and nothing else, so #001 was only reachable by paging to the end.
  ORDER_TYPES = %w[new oldest best].freeze

  # The body lives in Action Text, one named rich text per locale. Globalize still owns
  # title and subtitle; post_translations.description is left in place as a dormant backup
  # of the pre-Action-Text bodies and is no longer read.
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
                                      using: { tsearch: { prefix: true, any_word: true } }
  pg_search_scope :search_by_title, associated_against: { post_translations: [:title] },
                                    using: { tsearch: { prefix: true, any_word: true } }
  pg_search_scope :search_by_description, against: %i[search_body_en search_body_uk],
                                          using: { tsearch: { prefix: true, any_word: true } }

  mount_uploader :photo, PhotoUploader
  before_save :deactivate_previous_main_post, if: :main_post?
  before_save :mirror_search_bodies
  before_create :assign_entry_number

  validates :title, presence: true
  validates :subtitle, presence: true
  validate :description_present
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
  # не кращий варіант, оскільки імплементований status: :active
  scope :best, lambda {
    joins("LEFT JOIN ahoy_events ON ahoy_events.properties->>'post_id' = posts.id::text")
      .where(status: :active, ahoy_events: { name: 'Viewed Post' })
      .group('posts.id')
      .select('posts.*, COUNT(ahoy_events.id) AS views_count')
      .order('COUNT(ahoy_events.id) DESC')
  }
  scope :oldest, -> { where(status: :active).order(created_at: :asc) }

  # The entry either side of this one, by the series number the site prints. Nothing linked
  # posts to each other before: the only way out of an entry was back to the index or a
  # tag-similarity row, so a series could not be read as a series.
  scope :before, ->(post) { active.where(entry_number: ...post.entry_number).reorder(entry_number: :desc) }
  scope :after, ->(post) { active.where('entry_number > ?', post.entry_number).reorder(entry_number: :asc) }

  scope :similar_posts, lambda { |current_post|
    where.not(id: current_post.id)
         .includes(:tags)
         .where(tags: { title: current_post.similar_tags_titles }).where(status: :active)
         .limit(LIMIT_COUNT)
  }

  # The body for one locale, as an ActionText::RichText. Reading and writing `description`
  # without a locale means the current one, which keeps the admin form's param shape
  # (post[description] for the locale being edited, post[description_localizations] for the
  # rest) working exactly as it did before the body moved out of Globalize.
  def rich_body(locale = I18n.locale)
    public_send(RICH_TEXT_BODIES.fetch(locale.to_sym, :description_en))
  end

  def description
    rich_body
  end

  def description=(value)
    public_send(:"#{RICH_TEXT_BODIES.fetch(I18n.locale, :description_en)}=", value)
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
    public_send(:"rich_text_#{RICH_TEXT_BODIES.fetch(locale.to_sym, :description_en)}")&.body.present?
  end

  # #042 — a stored series number, printed the same way everywhere.
  def entry_label
    format('#%03d', entry_number) if entry_number.present?
  end

  def similar_tags_titles
    tags.limit(LIMIT_COUNT).pluck(:title)
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

  def deactivate_previous_main_post
    previous_main_post = Post.find_by(main_post: true)
    previous_main_post.update(main_post: false) if previous_main_post.present? && previous_main_post != self
  end
end
