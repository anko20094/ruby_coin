# frozen_string_literal: true

module Profile
  # Contacts and the three facts beside them. Every row is optional, and the panel is a bordered
  # box: drawn empty it would frame nothing, so it is drawn only when it has something in it.
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
