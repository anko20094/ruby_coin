# frozen_string_literal: true

class CreateCases < ActiveRecord::Migration[8.1]
  def change
    create_table :cases do |t|
      # Printed identity and ordering. `mark` is the label the design shows ("01"), position
      # is what the list is sorted by — they agree today but are not the same thing.
      t.string :slug, null: false
      t.string :mark, null: false
      t.integer :position, null: false

      t.boolean :own, null: false, default: false
      t.boolean :is_this_site, null: false, default: false

      # Deliberately English-only, as agreed: these read as data, not prose.
      t.string :year
      t.string :sector
      t.string :status

      # Translated scalars, each {"en" => …, "uk" => …}. Not Globalize and not Mobility:
      # every other field on this table already carries both languages inside JSONB because
      # that is the shape the handoff's YAML uses, and one mechanism beats two. See
      # redesign_plan.md §4.2 — the Mobility work is about Post.
      t.jsonb :title, null: false, default: {}
      t.jsonb :tagline, null: false, default: {}
      t.jsonb :role, null: false, default: {}
      t.jsonb :plain_heading, null: false, default: {}
      t.jsonb :engineering_heading, null: false, default: {}
      t.jsonb :engineering_sub, null: false, default: {}
      t.jsonb :scope_note, null: false, default: {}

      # Structured content. Counts are fixed by the design (four metrics, three paragraphs,
      # four claims, six cards, four quality figures) but not by the schema.
      t.jsonb :stack, null: false, default: []
      t.jsonb :metrics, null: false, default: []
      t.jsonb :quality, null: false, default: []
      t.jsonb :plain_body, null: false, default: []
      t.jsonb :mine, null: false, default: []
      t.jsonb :engineering_items, null: false, default: []

      t.timestamps
    end

    add_index :cases, :slug, unique: true
    add_index :cases, :position
  end
end
