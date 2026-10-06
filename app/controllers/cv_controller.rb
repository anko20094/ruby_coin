# frozen_string_literal: true

class CVController < ApplicationController
  def show
    @profile = Team.owner_cv
    @person = Team.owner
    @cases = Case.ordered.to_a
    # The career entries name their cases by slug. The list is already loaded, so the lookup
    # is a hash rather than a query per entry.
    @cases_by_slug = @cases.index_by(&:slug)

    cache_publicly(@cases)
  end
end
