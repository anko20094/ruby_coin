# frozen_string_literal: true

# A record's validation errors above its form, announced (role=alert) rather than only shown.
# Two skins: :site for the Devise screens on the theme, :admin for /management.
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
