# frozen_string_literal: true

module Management
  # ErrorsComponent in its admin skin, on the admin stylesheet.
  class ErrorsComponentPreview < ViewComponent::Preview
    layout 'component_preview_admin'

    # @label Admin
    def admin
      render(::ErrorsComponent.new(object: ::ErrorsComponentPreview.invalid_user, tone: :admin))
    end
  end
end
