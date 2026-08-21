# frozen_string_literal: true

# The one piece of brand: a faceted ruby, baked from the Phase 3 geometry —
# pointed-top hexagon (outer r46, table r22), six kite crown facets shaded for a
# fixed light at (30, 18).
#
# This is the static cut. W2 adds the cursor- and scroll-driven variants on top
# of the same geometry; this one stays as the prefers-reduced-motion path.
class GemComponent < ViewComponent::Base
  # Gradient ids have to be unique per instance — two gems on one page would
  # otherwise share the first set of definitions.
  def initialize(uid:)
    @uid = uid
    super()
  end

  attr_reader :uid
end
