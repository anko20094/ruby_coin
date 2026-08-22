# frozen_string_literal: true

class AddLockVersionToPosts < ActiveRecord::Migration[8.1]
  def change
    # Optimistic locking, so the editor can tell "someone else saved over you" from "your save
    # worked". Without a real version column the conflict banner the design asks for would be
    # decoration. Existing rows start at 0, which is what Rails expects.
    add_column :posts, :lock_version, :integer, null: false, default: 0
  end
end
