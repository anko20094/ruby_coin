# frozen_string_literal: true

class CreateCvTables < ActiveRecord::Migration[8.1]
  def change
    # The frame around the cases: who this is, how to reach them, when it was last checked.
    # One row, ever — CVProfile.current is the only way it is read.
    create_table :cv_profiles do |t|
      t.string :updated_on, null: false, default: ''

      t.jsonb :name, null: false, default: {}
      t.jsonb :role, null: false, default: {}
      t.jsonb :years, null: false, default: {}
      t.jsonb :summary, null: false, default: {}
      t.jsonb :location, null: false, default: {}
      t.jsonb :languages, null: false, default: {}
      t.jsonb :education, null: false, default: {}

      # [[key, label, href], …] — the order is the order it is printed in.
      t.jsonb :contact, null: false, default: []

      t.timestamps
    end

    # Career entries, stack groups and strengths share a table: they are all ordered lists of
    # small localised content, and none of them is queried on its own fields.
    create_table :cv_blocks do |t|
      t.string :kind, null: false
      t.integer :position, null: false
      t.jsonb :payload, null: false, default: {}
      # Career entries link into cases by slug; the chips on /work are built from this.
      t.jsonb :case_slugs, null: false, default: []

      t.timestamps
    end

    add_index :cv_blocks, %i[kind position]
  end
end
