# frozen_string_literal: true

module Statistics
  class CaseViewsQuery < BaseQuery
    def call
      counts = Ahoy::Event.where(name: 'Viewed Case')
                          .group(Arel.sql("properties->>'case_id'"))
                          .count

      Case.ordered.map { |kase| [kase, counts[kase.id.to_s].to_i] }
    end
  end
end
