# frozen_string_literal: true

# The CV was a table of ten rows with a model, a controller, a policy and CRUD screens — so
# changing two words meant navigating to another page and back, and reordering meant typing a
# number into a field. It is one document with three ordered lists in it, which is what
# Case::STRUCTURES already models well, so it becomes that. See redesign_plan.md §12.
#
# cv_blocks is deliberately left in place. The plan's own rule (§10.4) is that a table is not
# dropped until the migration has been checked against a copy of production; a follow-up drops
# it once this has run there.
class FoldCVBlocksIntoTheProfile < ActiveRecord::Migration[8.1]
  # Throwaway, so the migration keeps working after app/models/cv_block.rb is deleted.
  class Block < ActiveRecord::Base
    self.table_name = 'cv_blocks'
  end

  class Profile < ActiveRecord::Base
    self.table_name = 'cv_profiles'
  end

  EXPERIENCE_KEYS = %w[org title place period note body].freeze

  def up
    add_column :cv_profiles, :experience, :jsonb, null: false, default: []
    add_column :cv_profiles, :stack_groups, :jsonb, null: false, default: []
    add_column :cv_profiles, :strengths, :jsonb, null: false, default: []

    profile = Profile.first
    return if profile.nil?

    profile.update!(
      experience: rows('experience') { |block| experience_row(block) },
      stack_groups: rows('stack_group') { |block| block.payload.slice('label', 'items') },
      # A strength is one localised string, so the row is that string rather than a hash of one.
      strengths: rows('strength') { |block| block.payload['text'] }
    )
  end

  def down
    remove_column :cv_profiles, :experience
    remove_column :cv_profiles, :stack_groups
    remove_column :cv_profiles, :strengths
  end

  private

  def rows(kind, &)
    Block.where(kind: kind).order(:position, :id).map(&)
  end

  # Values are copied exactly as they are. Some are language pairs and some are bare strings —
  # a proper noun reads the same in both languages and the YAML wrote it once — and the reader
  # handles either, so normalising here would only lose information.
  def experience_row(block)
    block.payload.slice(*EXPERIENCE_KEYS).merge('case_slugs' => Array(block.case_slugs))
  end
end
