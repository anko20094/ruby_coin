# frozen_string_literal: true

# /contact — no form, by decision (redesign_plan.md §2). Every channel is already a real,
# monitored one in the CV, so the page hands them over directly instead of asking someone to
# type into a box and hope.
class ContactController < ApplicationController
  layout 'theme'

  def show
    @profile = CVProfile.current

    cache_publicly(@profile, last_modified: @profile.updated_at)
  end
end
