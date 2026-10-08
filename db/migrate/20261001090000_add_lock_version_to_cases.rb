# frozen_string_literal: true

# The case form posts every field on every save, so a tab opened before another tab's save would
# write the old value of everything the second tab did not touch. Optimistic locking turns that
# into a conflict the editor is told about.
class AddLockVersionToCases < ActiveRecord::Migration[8.1]
  def change
    add_column :cases, :lock_version, :integer, null: false, default: 0
  end
end
