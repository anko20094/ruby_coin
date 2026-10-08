# frozen_string_literal: true

class AddSearchBodiesToPosts < ActiveRecord::Migration[8.1]
  def change
    # Plain-text mirrors of the two Action Text bodies. pg_search cannot index
    # action_text_rich_texts.body directly without matching HTML tag names, so Post keeps a
    # stripped copy per locale and the search scopes stay on posts' own columns.
    add_column :posts, :search_body_en, :text
    add_column :posts, :search_body_uk, :text
  end
end
