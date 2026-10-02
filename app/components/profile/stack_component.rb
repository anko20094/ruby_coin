# frozen_string_literal: true

module Profile
  # The stack, grouped, and the strengths under it.
  class StackComponent < BaseComponent
    def initialize(profile:)
      @cv = profile
      super()
    end

    attr_reader :cv
  end
end
