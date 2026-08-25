# frozen_string_literal: true

class WorkController < ApplicationController
  layout 'theme'

  def index
    @profile = CVProfile.current
    @cases = Case.ordered.to_a
    # The career entries name their cases by slug. The list is already loaded, so the lookup
    # is a hash rather than a query per entry.
    @cases_by_slug = @cases.index_by(&:slug)

    cache_publicly([@profile, @cases])
  end

  def show
    # One load of the seven rows answers all three questions the page asks of the list: which
    # case this is, what is either side of it, and how many there are.
    slug = params.expect(:slug)
    cases = Case.ordered.to_a
    @case = cases.find { |kase| kase.slug == slug } or raise ActiveRecord::RecordNotFound
    @previous_case, @next_case = @case.neighbours(cases)
    @position = @case.number(cases)
    @total = cases.size

    # Which cases actually get opened is the one number that should decide the order of
    # /work, and nothing was counting it (handoff §9a). Recorded before the freshness check,
    # so a reader coming back to a page their browser has cached still counts as a reader.
    ViewTracking.record(self, @case)

    cache_publicly(@case, last_modified: @case.updated_at)
  end
end
