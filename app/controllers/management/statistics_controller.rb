# frozen_string_literal: true

module Management
  # What gets read. The screen used to answer only "how many post views in total" and split
  # each post's count across every title it had ever carried; it could not answer the question
  # the handoff says should decide the order of /work — which cases recruiters open.
  class StatisticsController < ApplicationController
    before_action :authorize_policy

    def index
      @totals = {
        today: Statistics::DailyViewsQuery.new.count,
        month: Statistics::MonthlyViewsQuery.new.count,
        year: Statistics::YearlyViewsQuery.new.count,
        all: Statistics::TotalViewsQuery.new.count
      }
      @post_views = Statistics::PostViewsQuery.new.count
      @case_views = Statistics::CaseViewsQuery.new.count
    end

    private

    def authorize_policy
      authorize :statistics
    end
  end
end
