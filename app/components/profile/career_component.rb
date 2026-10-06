# frozen_string_literal: true

module Profile
  class CareerComponent < BaseComponent
    attr_reader :cv

    def initialize(profile:, cases_by_slug: {})
      @cv = profile
      @cases_by_slug = cases_by_slug

      super()
    end

    def cases_for(entry) = entry[:case_slugs].filter_map { |slug| @cases_by_slug[slug] }
  end
end
