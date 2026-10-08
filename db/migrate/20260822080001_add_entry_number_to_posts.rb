# frozen_string_literal: true

class AddEntryNumberToPosts < ActiveRecord::Migration[8.1]
  def up
    add_column :posts, :entry_number, :integer

    # The journal prints a stored number (#042), never a row index — pagination would
    # renumber every page. Oldest post is #1, so the series reads in publication order.
    execute <<~SQL.squish
      UPDATE posts
      SET entry_number = numbered.position
      FROM (SELECT id, ROW_NUMBER() OVER (ORDER BY created_at, id) AS position FROM posts) AS numbered
      WHERE posts.id = numbered.id
    SQL

    add_index :posts, :entry_number, unique: true
  end

  def down
    remove_column :posts, :entry_number
  end
end
