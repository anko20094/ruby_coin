# frozen_string_literal: true

# `updated_on` is one of the two names Active Record treats as a magic update timestamp
# (`timestamp_attributes_for_update` is `["updated_at", "updated_on"]`). The column holds a
# hand-written line — "2026·08·18", the date the CV's figures were last checked — so every
# save of the CV form silently overwrote it with a raw UTC timestamp, and /work then printed
# "figures read from production · 2026-08-24 18:51:09 UTC".
#
# The fix is the name. `figures_as_of` says what the value is and is not magic.
class RenameCVProfilesUpdatedOn < ActiveRecord::Migration[8.1]
  def change
    rename_column :cv_profiles, :updated_on, :figures_as_of
  end
end
