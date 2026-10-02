# frozen_string_literal: true

module Management
  # What gets read: views per post and per case — the latter being what should decide the
  # order of /work.
  class StatisticsController < ApplicationController
    before_action :authorize_policy

    def index
      @totals = {
        today: Statistics::ViewsQuery.call(:day),
        month: Statistics::ViewsQuery.call(:month),
        year: Statistics::ViewsQuery.call(:year),
        all: Statistics::ViewsQuery.call
      }
      @post_views = Statistics::PostViewsQuery.call
      @case_views = Statistics::CaseViewsQuery.call
    end

    private

    def authorize_policy
      authorize [:management, :statistics]
    end
  end
end
