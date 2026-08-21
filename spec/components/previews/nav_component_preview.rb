# frozen_string_literal: true

class NavComponentPreview < ViewComponent::Preview
  # @label Nav (English)
  def default
    render(NavComponent.new(current: :work))
  end

  # @label Nav (Ukrainian)
  def ukrainian
    I18n.with_locale(:uk) { render(NavComponent.new(current: :work)) }
  end

  # @label Nav (no active section)
  def without_current
    render(NavComponent.new)
  end
end
