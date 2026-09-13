# frozen_string_literal: true

# The one piece of brand: a faceted ruby.
#
# Geometry is a pointed-top hexagon — outer radius 46, table radius 22 — cut
# into six kite crown facets. Each facet's fill is computed from how close its
# centroid sits to a virtual light, which is what makes the stone read as a
# stone rather than a red polygon.
#
# Three variants, from the design system:
#
#   :logo    static, light fixed upper-left. Nav and footer, 26–28px.
#   :hero    light follows the cursor, scroll drives rotation. 400px.
#   :anchor  scroll rotation only, light fixed. 90px, beside section headers.
#
# The server always paints a finished gem, so it is correct with JavaScript
# disabled and under prefers-reduced-motion. For :hero and :anchor the Stimulus
# controller then recomputes the same values live — the shading maths exists
# twice on purpose, here and in theme/ruby_controller.js. Change one, change
# both.
class GemComponent < ViewComponent::Base
  VARIANTS = %i[logo hero anchor].freeze

  CENTRE = 50.0
  OUTER_RADIUS = 46.0
  TABLE_RADIUS = 22.0
  FACET_COUNT = 6

  # Where the light sits at rest. The logo's is a touch further round than the
  # interactive cuts', which is how the prototype had it.
  LIGHTS = { logo: [30.0, 18.0], hero: [28.0, 18.0], anchor: [28.0, 18.0] }.freeze

  Facet = Struct.new(:index, :points, :centroid, :brightness, keyword_init: true)

  def initialize(uid:, variant: :logo, size: nil)
    raise ArgumentError, "variant must be one of #{VARIANTS.join(', ')}" unless VARIANTS.include?(variant.to_sym)

    @uid = uid
    @variant = variant.to_sym
    @size = size
    super()
  end

  attr_reader :uid, :variant, :size

  def interactive? = variant != :logo
  def glow? = interactive?
  def light = LIGHTS.fetch(variant)

  # The size is a ceiling, not a fixed width: a 400px hero gem inside a one-column grid used to
  # pin that column's min-content at 400px, and the home page came out 436px wide on a 375px
  # phone with the lede clipped mid-word.
  #
  # `max-width` rather than `min()`, though. A width computed from a percentage makes this a
  # replaced element of indefinite size, so its max-content contribution is the 300px default an
  # SVG falls back to — not the 72px it draws at. The floating back-to-top button is shrink-to-
  # fit around exactly this gem: it came out 312px wide, and the invisible three-quarters of it
  # covered the footer's contact links.
  def style
    "width: #{size}px; max-width: 100%; height: auto; aspect-ratio: 1" if size
  end

  def facets
    @facets ||= Array.new(FACET_COUNT) do |index|
      following = (index + 1) % FACET_COUNT
      points = [outer[index], outer[following], inner[following], inner[index]]
      centroid = [points.sum { |p| p[0] } / 4.0, points.sum { |p| p[1] } / 4.0]
      Facet.new(index:, points:, centroid:, brightness: brightness_at(centroid))
    end
  end

  def outer = @outer ||= ring(OUTER_RADIUS)
  def inner = @inner ||= ring(TABLE_RADIUS)

  def table_brightness = @table_brightness ||= brightness_at([CENTRE, CENTRE])

  # Stops for one facet: brighter towards the light, deeper away from it.
  def facet_stops(facet)
    [shade([1, facet.brightness + 0.18].min), shade(facet.brightness), shade([0, facet.brightness - 0.22].max)]
  end

  # The gradient runs from the light's side of the stone to the far side.
  def facet_gradient_line(facet)
    dx = light[0] - facet.centroid[0]
    dy = light[1] - facet.centroid[1]
    length = Math.hypot(dx, dy)
    length = 1.0 if length.zero?
    vector_x = dx / length
    vector_y = dy / length

    {
      x1: round(CENTRE + (vector_x * 30)), y1: round(CENTRE + (vector_y * 30)),
      x2: round(CENTRE - (vector_x * 30)), y2: round(CENTRE - (vector_y * 30))
    }
  end

  # The table is damped a little, so the crown reads brighter than the middle.
  def table_stops
    [
      shade([1, table_brightness + 0.25].min), shade((table_brightness * 0.85) + 0.1),
      shade([0, table_brightness - 0.2].max)
    ]
  end

  # A specular shimmer rides the brightest facet, but only once it is genuinely lit.
  def specular
    brightest = facets.max_by(&:brightness)
    return if brightest.brightness < 0.5

    {
      points: polygon(inset(brightest.points, brightest.centroid, 0.35)),
      opacity: round((brightest.brightness - 0.5) * 1.8)
    }
  end

  # A bright dot at the centre when the table itself catches the light.
  def crown
    return if table_brightness <= 0.4

    { radius: round(1.0 + (table_brightness * 1.4)), opacity: round((table_brightness - 0.4) * 1.8) }
  end

  def polygon(points)
    points.map { |point| "#{round(point[0])},#{round(point[1])}" }.join(' ')
  end

  private

  def ring(radius)
    Array.new(FACET_COUNT) do |index|
      angle = (-90 + (index * 60)) * Math::PI / 180
      [CENTRE + (radius * Math.cos(angle)), CENTRE + (radius * Math.sin(angle))]
    end
  end

  # Brightness falls off over 70 units and is squared, which hardens the split
  # between lit and unlit facets.
  def brightness_at(centroid)
    distance = Math.hypot(centroid[0] - light[0], centroid[1] - light[1])
    (1 - [1, distance / 70.0].min)**2
  end

  # Deep blood in shadow, bright fire in the light, hue drifting warmer as it darkens.
  def shade(brightness)
    lightness = 14 + (brightness * 64)
    chroma = 0.08 + (brightness * 0.22)
    hue = 14 + ((1 - brightness) * 6)
    format('oklch(%.1f%% %.3f %.1f)', lightness, chroma, hue)
  end

  def inset(points, centroid, factor)
    points.map do |point|
      [centroid[0] + ((point[0] - centroid[0]) * factor), centroid[1] + ((point[1] - centroid[1]) * factor)]
    end
  end

  # Trailing zeros are noise in the markup: 50.0 and 50 paint the same pixel.
  def round(value)
    rounded = value.round(2)
    rounded == rounded.to_i ? rounded.to_i : rounded
  end
end
