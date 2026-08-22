# frozen_string_literal: true

class WorkController < ApplicationController
  layout 'theme'

  def index
    @cv = Portfolio.cv
    @cases = Case.ordered
    # The career track links into cases by slug; one lookup beats one query per chip.
    @cases_by_slug = @cases.index_by(&:slug)
  end

  def show
    @case = Case.find_by!(slug: params.expect(:slug))
    @previous_case, @next_case = @case.neighbours
    @position = @case.number
    @total = Case.count
  end
end
