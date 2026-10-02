# frozen_string_literal: true

# One row of the journal index: number · date · title · byline over tags.
#
# The whole row is a single <a>, not a div with a click handler — keyboard, middle-click and
# "open in new tab" all have to work.
class JournalEntryComponent < ViewComponent::Base
  def initialize(post:, first: false)
    @post = post
    @first = first
    super()
  end

  attr_reader :post

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
end
