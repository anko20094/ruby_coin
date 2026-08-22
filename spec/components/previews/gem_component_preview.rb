# frozen_string_literal: true

class GemComponentPreview < ViewComponent::Preview
  # Static, light fixed upper-left. This is the nav and footer cut, and the one
  # everybody sees under prefers-reduced-motion.
  # @param size number
  def logo(size: 120)
    render(GemComponent.new(uid: 'preview-logo', size: size))
  end

  # Light follows the cursor, scroll rotates the crown, the stone tilts toward
  # the pointer. Move your cursor anywhere in the preview pane.
  # @param size number
  def hero(size: 400)
    render(GemComponent.new(uid: 'preview-hero', variant: :hero, size: size))
  end

  # Scroll rotation only, light fixed. Sits beside section headers.
  # @param size number
  def anchor(size: 90)
    render(GemComponent.new(uid: 'preview-anchor', variant: :anchor, size: size))
  end
end
