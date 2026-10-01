# frozen_string_literal: true

class WorkController < ApplicationController
  layout 'theme'

  def index
    @cases = Case.ordered.to_a
    # Each card shows who built the project. Read once for the whole page rather than once per
    # card, so the roster is parsed a single time.
    @team_by_slug = @cases.to_h { |kase| [kase.slug, Team.for_case(kase.slug)] }

    cache_publicly(@cases, Team.version)
  end

  def show
    # One load of the seven rows answers all three questions the page asks of the list: which
    # case this is, what is either side of it, and how many there are.
    slug = params.expect(:slug)
    cases = Case.ordered.to_a
    @case = cases.find { |kase| kase.slug == slug } or raise ActiveRecord::RecordNotFound
    @previous_case, @next_case = @case.neighbours(cases)
    @total = cases.size
    @team = Team.for_case(@case.slug)

    # Which cases actually get opened is the one number that should decide the order of
    # /work, and nothing was counting it (handoff §9a). Recorded before the freshness check,
    # so a reader coming back to a page their browser has cached still counts as a reader.
    ViewTracking.record(self, @case)

    cache_publicly(cases, Team.version)
  end
end
