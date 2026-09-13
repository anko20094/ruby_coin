# frozen_string_literal: true

# The hiring page: the same evidence as /team/danyil, in a recruiter's language and printable.
#
# Both render from the one CV in the database, imported from config/portfolio/cv.yml — do not
# let them drift into two documents.
class CVController < ApplicationController
  def show
    # A database that has never run `rake cv:import` has no CV. CVProfile.current hands back an
    # unsaved row so the page renders rather than raising, and the page then says it is not
    # filled in — the same designed state a person page has, rather than a heading over nothing.
    @profile = CVProfile.current
    @person = Team.owner
    @cases = Case.ordered.to_a
    # The career entries name their cases by slug. The list is already loaded, so the lookup
    # is a hash rather than a query per entry.
    @cases_by_slug = @cases.index_by(&:slug)

    cache_publicly([@profile, @cases, Team.version], last_modified: @profile.updated_at)
  end
end
