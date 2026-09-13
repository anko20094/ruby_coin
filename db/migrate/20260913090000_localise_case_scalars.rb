# frozen_string_literal: true

# `year`, `sector` and `status` were left as plain strings on the assumption that a date range
# and a sector name read the same in both languages. They do not: a Ukrainian case page printed
# "2022—present", "publishing · education" and "built from zero · 19 contributors" in English,
# in the middle of otherwise fully Ukrainian copy. They become language pairs like every other
# translated field on this table.
class LocaliseCaseScalars < ActiveRecord::Migration[8.1]
  FIELDS = %i[year sector status].freeze

  def up
    FIELDS.each do |field|
      add_column :cases, :"#{field}_pair", :jsonb, default: {}, null: false

      # Both languages get the old string, so nothing renders blank between this and the
      # import that puts the real translation in.
      execute <<~SQL.squish
        UPDATE cases
        SET #{field}_pair = jsonb_build_object('en', COALESCE(#{field}, ''), 'uk', COALESCE(#{field}, ''))
      SQL

      remove_column :cases, field
      rename_column :cases, :"#{field}_pair", field
    end
  end

  def down
    FIELDS.each do |field|
      add_column :cases, :"#{field}_text", :string

      execute "UPDATE cases SET #{field}_text = #{field} ->> 'en'"

      remove_column :cases, field
      rename_column :cases, :"#{field}_text", field
    end
  end
end
