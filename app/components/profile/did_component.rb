# frozen_string_literal: true

module Profile
  class DidComponent < BaseComponent
    attr_reader :lines

    def initialize(lines:, dense: false)
      @lines = lines
      @dense = dense

      super()
    end

    def css_class = @dense ? 'pf-did pf-did--dense' : 'pf-did'
  end
end
