# frozen_string_literal: true

class GemComponentPreview < ViewComponent::Preview
  # The static cut, as it renders in the nav and footer.
  def default
    render(GemComponent.new(uid: 'preview'))
  end
end
