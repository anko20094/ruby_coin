# frozen_string_literal: true

# The studio page: the same roster as /team at a lower density, and the way into it from the
# main nav. Both read config/portfolio/people.yml, so a new person is one entry rather than
# three edits.
class StudioController < ApplicationController
  def show
    @people = Team.crew
    @alumni = Team.alumni

    cache_publicly
  end
end
