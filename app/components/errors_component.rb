# frozen_string_literal: true

class ErrorsComponent < ViewComponent::Base
  TONES = { site: 'au-errors', admin: 'mg-errors' }.freeze

  def initialize(object:, tone: :admin)
    raise ArgumentError, "tone must be one of #{TONES.keys.join(', ')}" unless TONES.key?(tone)

    @object = object
    @tone = tone

    super()
  end

  def render? = messages.any?

  def messages = @object&.errors&.full_messages || []

  def css_class = TONES.fetch(@tone)
end
