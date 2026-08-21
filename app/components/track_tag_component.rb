# frozen_string_literal: true

# The device that separates the two registers on a case page, and labels the
# sections of the work index. Colour is the whole signal, so it is passed in.
#
# On the index the label *is* the section heading, so callers pass heading: :h2;
# above a case-page h2 it stays a plain span.
class TrackTagComponent < ViewComponent::Base
  TONES = %i[ruby soft].freeze

  def initialize(label:, tone:, heading: :span)
    raise ArgumentError, "tone must be one of #{TONES.join(', ')}" unless TONES.include?(tone.to_sym)

    @label = label
    @tone = tone.to_sym
    @heading = heading
    super()
  end

  attr_reader :label, :tone, :heading
end
