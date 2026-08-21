# frozen_string_literal: true

class FooterComponentPreview < ViewComponent::Preview
  def default
    render(FooterComponent.new)
  end

  # @label Footer (Ukrainian)
  def ukrainian
    I18n.with_locale(:uk) { render(FooterComponent.new) }
  end
end
