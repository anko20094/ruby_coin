# frozen_string_literal: true

class StudioController < ApplicationController
  def show
    @people = Team.crew
    @alumni = Team.alumni

    cache_publicly
  end
end
