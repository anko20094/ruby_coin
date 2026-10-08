# frozen_string_literal: true

class FooterComponentPreview < ViewComponent::Preview
  def default
    render(FooterComponent.new)
  end

  # On /contact, which is the call itself: the closing line is left out.
  def quiet
    render(FooterComponent.new(cta: false))
  end

  # @label Footer (Ukrainian)
  def ukrainian
    I18n.with_locale(:uk) { render(FooterComponent.new) }
  end
end
