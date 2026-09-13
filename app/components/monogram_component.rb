# frozen_string_literal: true

# Initials in a frame, standing in for a photograph. One crop, one treatment, everywhere a
# person appears — so when a real photograph arrives it replaces the fill and nothing in the
# layout moves. A machine on the roster gets a ruby CI flag across the bottom: the reader is
# told what it is without a footnote.
class MonogramComponent < ViewComponent::Base
  RINGS = %i[ink mute paper].freeze

  # Below this the CI label is a red smudge rather than a word, so it is not drawn — and the
  # ring turns ruby in its place, because a machine seated unlabelled among four faces is the
  # one thing this design must not do. The component decides it rather than a container query:
  # an element cannot query its own container.
  COMPACT_BELOW = 40

  def self.of(person, **) = new(initials: person.short, seed: person.id, machine: person.machine?, **)

  def initialize(initials:, size:, seed: initials, machine: false, ring: :ink)
    raise ArgumentError, "ring must be one of #{RINGS.join(', ')}" unless RINGS.include?(ring)

    @initials = initials
    @size = size
    @seed = seed
    @machine = machine
    @ring = ring
    super()
  end

  attr_reader :initials, :size, :ring

  def machine? = @machine

  # The gradient leans a different way for each person, seeded from the id so one person is
  # drawn the same way every time.
  def angle = 140 + (@seed.to_s.sum % 40)

  def compact? = size < COMPACT_BELOW

  def css_class
    [
      'rc-monogram', "rc-monogram--#{ring}",
      ('rc-monogram--machine' if machine?), ('rc-monogram--compact' if compact?)
    ].compact.join(' ')
  end

  def style = "--monogram-size: #{size}px; --monogram-angle: #{angle}deg"
end
