# frozen_string_literal: true

class HexRingsComponent < ViewComponent::Base
  # Outer to inner, each a hexagon drawn in the stone's own outline around the centre.
  RINGS = [
    '100,4 183.1,52 183.1,148 100,196 16.9,148 16.9,52',
    '100,24 165.8,62 165.8,138 100,176 34.2,138 34.2,62',
    '100,44 148.5,72 148.5,128 100,156 51.5,128 51.5,72',
    '100,64 131.2,82 131.2,118 100,136 68.8,118 68.8,82'
  ].freeze

  attr_reader :css

  # css: the placement class of the page that draws the rings.
  def initialize(css: nil)
    @css = css

    super()
  end
end
