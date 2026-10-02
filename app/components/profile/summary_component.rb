# frozen_string_literal: true

module Profile
  # The summary paragraph at the top of a CV.
  class SummaryComponent < BaseComponent
    def initialize(profile:)
      @cv = profile
      super()
    end

    attr_reader :cv
  end
end
