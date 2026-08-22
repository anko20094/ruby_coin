# frozen_string_literal: true

class CreateJournalBlocks < ActiveRecord::Migration[8.1]
  def change
    # The three block kinds the slash menu inserts. They are Action Text attachables rather
    # than baked-in HTML, so the partials stay the single implementation — editing a partial
    # re-renders every article that uses the block.
    create_table :journal_blocks do |t|
      t.string :kind, null: false
      t.jsonb :payload, null: false, default: {}

      t.timestamps
    end
  end
end
