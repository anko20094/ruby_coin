# frozen_string_literal: true

module Profile
  class PendingComponent < BaseComponent
    def initialize(body: nil)
      @body = body

      super()
    end

    def body = @body || t('profile.pending.body')
  end
end
