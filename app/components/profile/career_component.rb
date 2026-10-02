# frozen_string_literal: true

module Profile
  # The career entries. cases_by_slug is empty on a person page: the projects are the "worked
  # on" list below it there, and the same links twice on one page is a list pretending to be two.
  class CareerComponent < BaseComponent
    def initialize(profile:, cases_by_slug: {})
      @cv = profile
      @cases_by_slug = cases_by_slug
      super()
    end

    attr_reader :cv

    def cases_for(entry) = entry[:case_slugs].filter_map { |slug| @cases_by_slug[slug] }
  end
end
