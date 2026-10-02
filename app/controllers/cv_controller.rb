# frozen_string_literal: true

# The hiring page: the same evidence as /team/danyil, in a recruiter's language and printable.
#
# Both render from the one CV in config/portfolio/cv.yml — do not let them drift into two
# documents.
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
