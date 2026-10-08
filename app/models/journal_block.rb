# frozen_string_literal: true

class JournalBlock < ApplicationRecord
  include ActionText::Attachable

  KINDS = %w[code callout embed].freeze
  TONES = %w[note warn].freeze

  # Which payload keys each kind requires. Anything else in the payload is ignored.
  REQUIRED_KEYS = {
    'code' => %w[source],
    'callout' => %w[body],
    'embed' => %w[url]
  }.freeze

  validates :kind, inclusion: { in: KINDS }
  validate :payload_shape

  def to_partial_path
    'journal_blocks/journal_block'
  end

  def language = payload['language'].presence
  def source = payload['source'].to_s
  def body = payload['body'].to_s
  # Not #caption: that name is one of Action Text's own attachment attributes and loses to
  # it when the block is rendered from inside an <action-text-attachment>.
  def embed_caption = payload['caption'].presence
  def url = payload['url'].to_s

  # What Post mirrors into search_body_* and counts for reading time in place of the block.
  def attachable_plain_text_representation(_caption = nil)
    " #{[source, body, embed_caption].compact_blank.join(' ')} "
  end

  def tone
    TONES.include?(payload['tone']) ? payload['tone'] : 'note'
  end

  private

  def payload_shape
    return unless KINDS.include?(kind)

    missing = REQUIRED_KEYS.fetch(kind).reject { |key| payload[key].present? }
    errors.add(:payload, :blank) if missing.any?
    errors.add(:payload, :invalid) if kind == 'embed' && payload['url'].present? && !http_url?
  end

  def http_url?
    uri = URI.parse(payload['url'].to_s)
    uri.is_a?(URI::HTTP) && uri.host.present?
  rescue URI::InvalidURIError
    false
  end
end
