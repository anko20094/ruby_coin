# frozen_string_literal: true

# A face in a frame: a photograph where there is one, initials where there is not. One crop,
# one treatment, everywhere a person appears — the frame, the ring and the radius are the same
# either way, so a photograph arriving moves nothing in the layout. A machine on the roster gets
# a ruby CI flag across the bottom: the reader is told what it is without a footnote.
class MonogramComponent < ViewComponent::Base
  RINGS = %i[ink mute paper].freeze

  # Below this the CI label is a red smudge rather than a word, so it is not drawn — and the
  # ring turns ruby in its place, because a machine seated unlabelled among four faces is the
  # one thing this design must not do. The component decides it rather than a container query:
  # an element cannot query its own container.
  COMPACT_BELOW = 40

  def self.of(person, **)
    new(initials: person.short, seed: person.id, machine: person.machine?, photo: person.photo, **)
  end

  def initialize(initials:, size:, seed: initials, machine: false, ring: :ink, photo: nil)
    raise ArgumentError, "ring must be one of #{RINGS.join(', ')}" unless RINGS.include?(ring)

    @initials = initials
    @size = size
    @seed = seed
    @machine = machine
    @ring = ring
    @photo = photo
    super()
  end

  attr_reader :initials, :size, :ring, :photo

  def photo? = photo.present?

  def machine? = @machine

  # The gradient leans a different way for each person, seeded from the id so one person is
  # drawn the same way every time.
  def angle = 140 + (@seed.to_s.sum % 40)

  def compact? = size < COMPACT_BELOW

  def css_class
    [
      'rc-monogram', "rc-monogram--#{ring}",
      ('rc-monogram--machine' if machine?), ('rc-monogram--compact' if compact?),
      ('rc-monogram--photo' if photo?)
    ].compact.join(' ')
  end

  # Twice the drawn size, capped at what the file actually holds: the largest stone on the site
  # is 280px, and asking for 560 on a phone strip that draws it at 32 wastes the visit.
  def photo_width = [size * 2, 560].min

  def style = "--monogram-size: #{size}px; --monogram-angle: #{angle}deg"
end
