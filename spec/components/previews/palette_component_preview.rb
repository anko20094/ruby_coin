# frozen_string_literal: true

class PaletteComponentPreview < ViewComponent::Preview
  # @label Palette (button; press it, or ⌘K / Ctrl K, to open)
  def default
    render(PaletteComponent.new)
  end
end
