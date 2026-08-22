# frozen_string_literal: true

class WorkController < ApplicationController
  layout 'theme'

  def index
    @profile = CVProfile.current
    @experience = CVBlock.experience
    @stack_groups = CVBlock.stack_groups
    @strengths = CVBlock.strengths
    @cases = Case.ordered
  end

  def show
    @case = Case.find_by!(slug: params.expect(:slug))
    @previous_case, @next_case = @case.neighbours
    @position = @case.number
    @total = Case.count
  end
end
