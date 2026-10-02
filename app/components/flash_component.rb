# frozen_string_literal: true

# The flash region, on both layouts. One live region, announced. A message leaves on its own
# after a while (longer for alerts), holds while it is hovered or focused, and can be closed.
#
# The admin passes frame_id, so a Turbo Stream can replace the region after a frame action
# (ApplicationHelper#flash_stream).
class FlashComponent < ViewComponent::Base
  # Rails, Devise and Pundit name the same two states differently; the design has two tones.
  ALERT_KEYS = %w[alert error danger].freeze

  # Milliseconds on screen; an alert usually asks the reader to do something, so it stays longer.
  LIFETIME = { 'notice' => 6000, 'alert' => 10_000 }.freeze

  Message = Data.define(:tone, :text) do
    def role = tone == 'alert' ? 'alert' : 'status'
    def lifetime = LIFETIME.fetch(tone)
  end

  def initialize(flash:, frame_id: nil)
    @flash = flash
    @frame_id = frame_id
    super()
  end

  attr_reader :frame_id

  def messages
    @flash.filter_map do |type, text|
      next if text.blank? || !text.is_a?(String)

      Message.new(tone: self.class.tone(type), text:)
    end
  end

  def self.tone(type) = ALERT_KEYS.include?(type.to_s) ? 'alert' : 'notice'
end
