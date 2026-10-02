# frozen_string_literal: true

module Profile
  # A CV nobody has written yet. It says so, and why, rather than inventing a career for a named
  # colleague. /cv has no contributions above it to point at, so it passes its own body.
  class PendingComponent < BaseComponent
    def initialize(body: nil)
      @body = body
      super()
    end

    def body = @body || t('profile.pending.body')
  end
end
