# frozen_string_literal: true

module Profile
  class ContactPanelComponent < BaseComponent
    def initialize(profile:)
      @cv = profile

      super()
    end

    def render? = rows.any? || facts.any?

    def rows = @rows ||= @cv.contact_rows

    def facts
      @facts ||= { location: @cv.location, languages: @cv.languages, education: @cv.education }
                 .compact_blank
    end
  end
end
