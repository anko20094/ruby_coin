# frozen_string_literal: true

module Statistics
  # How many times a post was read: today, this month, this year, or ever.
  class ViewsQuery < BaseQuery
    PERIODS = { day: :all_day, month: :all_month, year: :all_year }.freeze

    def initialize(period = nil)
      super()
      @period = period
    end

    def call
      events = Ahoy::Event.where(name: 'Viewed Post')
      events = events.where(time: Time.zone.now.public_send(PERIODS.fetch(@period))) if @period
      events.count
    end
  end
end
