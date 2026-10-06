# frozen_string_literal: true

module Profile
  class BaseComponent < ViewComponent::Base
    delegate :rich, :plain, to: :helpers
  end
end
