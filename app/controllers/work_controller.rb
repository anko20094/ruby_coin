# frozen_string_literal: true

class WorkController < ApplicationController
  layout 'work'

  def index
    @cv = Portfolio.cv
    @cases = Portfolio.cases
  end

  def show
    @case = Portfolio.case!(params[:slug])
    @previous_case, @next_case = Portfolio.neighbours(@case['slug'])
    @position = Portfolio.position(@case['slug']) + 1
    @total = Portfolio.cases.size
  end
end
