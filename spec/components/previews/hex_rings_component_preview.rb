# frozen_string_literal: true

class HexRingsComponentPreview < ViewComponent::Preview
  # The rings behind a page head's anchor gem; the placement class sizes and places them.
  def page_head
    render(HexRingsComponent.new(css: 'rc-pagehead__rings'))
  end

  # Unplaced, as the SVG draws itself.
  def bare
    render(HexRingsComponent.new)
  end
end
