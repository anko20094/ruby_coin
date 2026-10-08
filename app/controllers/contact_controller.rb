# frozen_string_literal: true

class ContactController < ApplicationController
  def show
    @profile = Team.owner_cv

    cache_publicly
  end
end
