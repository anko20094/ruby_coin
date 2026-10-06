# frozen_string_literal: true

class TrackTagComponent < ViewComponent::Base
  TONES = %i[ruby soft].freeze

  attr_reader :label, :tone, :heading

  def initialize(label:, tone:, heading: :span)
    raise ArgumentError, "tone must be one of #{TONES.join(', ')}" unless TONES.include?(tone.to_sym)

    @label = label
    @tone = tone.to_sym
    @heading = heading

    super()
  end
end
