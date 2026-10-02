# frozen_string_literal: true

# /contact — no form, by decision (docs/decisions.md). Every channel is already a real,
# monitored one in the CV, so the page hands them over directly instead of asking someone to
# type into a box and hope.
class ContactController < ApplicationController
  def show
    @profile = Team.owner_cv

    cache_publicly
  end
end
