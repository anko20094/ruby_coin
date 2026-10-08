# frozen_string_literal: true

module Profile
  class SummaryComponent < BaseComponent
    attr_reader :cv

    def initialize(profile:)
      @cv = profile

      super()
    end
  end
end
