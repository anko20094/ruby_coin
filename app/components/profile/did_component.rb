# frozen_string_literal: true

module Profile
  # What someone did on a project, one line each, marked with an 8×1px ruby bar.
  class DidComponent < BaseComponent
    def initialize(lines:, dense: false)
      @lines = lines
      @dense = dense
      super()
    end

    attr_reader :lines

    def css_class = @dense ? 'pf-did pf-did--dense' : 'pf-did'
  end
end
