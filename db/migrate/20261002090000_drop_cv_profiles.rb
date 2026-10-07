# frozen_string_literal: true

# The owner's CV is read from config/portfolio/cv.yml, as every other CV is from people.yml, so
# the row the deploy kept rewriting from that file has no reader left.
class DropCVProfiles < ActiveRecord::Migration[8.1]
  def change
    drop_table :cv_profiles do |t|
      t.jsonb :contact, default: [], null: false
      t.jsonb :education, default: {}, null: false
      t.jsonb :experience, default: [], null: false
      t.string :figures_as_of, default: '', null: false
      t.jsonb :languages, default: {}, null: false
      t.jsonb :location, default: {}, null: false
      t.jsonb :name, default: {}, null: false
      t.jsonb :role, default: {}, null: false
      t.jsonb :stack_groups, default: [], null: false
      t.jsonb :strengths, default: [], null: false
      t.jsonb :summary, default: {}, null: false
      t.jsonb :years, default: {}, null: false
      t.timestamps
    end
  end
end
