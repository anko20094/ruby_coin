# frozen_string_literal: true

# The CV is config/portfolio/cv.yml (docs/decisions.md §4), and cv_blocks was folded into
# cv_profiles and then dropped with it in everything but the table. Nothing reads it, and it
# never existed on production: master's schema has no CV tables at all.
class DropCVBlocks < ActiveRecord::Migration[8.1]
  def change
    drop_table :cv_blocks do |t|
      # In the order db/schema.rb lists them, so a rollback dumps the same file.
      t.jsonb :case_slugs, default: [], null: false
      t.datetime :created_at, null: false
      t.string :kind, null: false
      t.jsonb :payload, default: {}, null: false
      t.integer :position, null: false
      t.datetime :updated_at, null: false

      t.index %i[kind position], name: 'index_cv_blocks_on_kind_and_position'
    end
  end
end
