# frozen_string_literal: true

class ListKeysComponentPreview < ViewComponent::Preview
  # Drawn hidden until list-nav connects, so the preview shows nothing without that controller.
  def default
    render(ListKeysComponent.new)
  end
end
