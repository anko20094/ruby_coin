# frozen_string_literal: true

class JournalEntryComponent < ViewComponent::Base
  LEAD_LIMIT = 140

  attr_reader :post

  # `heading: :h3` where the rows sit under a heading of their own (the journal's years).
  def initialize(post:, first: false, heading: :h2)
    @post = post
    @first = first
    @heading = heading

    super()
  end

  def heading_tag = @heading == :h3 ? :h3 : :h2

  def css_classes
    ['jn-entry', ('jn-entry--first' if @first)].compact.join(' ')
  end

  # Dates are mono and dot-separated in both locales — the digits carry the meaning, so this
  # deliberately does not go through I18n.l.
  def date
    post.created_at.strftime('%Y·%m·%d')
  end

  def byline
    [post.user&.nickname, I18n.t('journal.minutes', count: post.reading_minutes)].compact_blank.join(' · ')
  end

  def tag_list
    post.tags.map { |tag| "##{tag.title}" }.join(' ')
  end

  # The subtitle, which every post has, as one plain line short enough for the preview card.
  def lead
    ProseHelper.plain(post.subtitle).squish.truncate(LEAD_LIMIT, separator: ' ')
  end

  def lead_id = "jn-lead-#{post.id || object_id}"

  def preview_meta
    [I18n.t('journal.minutes', count: post.reading_minutes), tag_list.presence].compact.join(' · ')
  end
end
