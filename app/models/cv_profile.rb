# frozen_string_literal: true

# The CV: who this is, the summary, the contact column, and the three ordered lists that /cv
# and /team/danyil print — career, stack groups, strengths.
#
# All of it is one row. The lists used to be a `cv_blocks` table with its own model,
# controller, policy and CRUD screens, which made a CV of ten lines behave like a collection
# you browse: changing two words was a page navigation, and reordering was typing a number
# into a field. It is one document, edited whole a few times a year, so it is stored and
# edited as one. See redesign_plan.md §12.
#
# A singleton. Everything reads it through .current, which builds an unsaved row when the
# table is empty so the page renders on a fresh database instead of raising.
class CVProfile < ApplicationRecord
  include StructuredJson

  LOCALISED_SCALARS = %i[name role years summary location languages education].freeze

  # `count` is what the CV has today and what a blank form starts from; it is a hint beside
  # the heading, not a limit.
  STRUCTURES = {
    experience: {
      count: 4,
      # `body` is the only one the CV pages print through ProseHelper#rich; the rest are escaped,
      # so an editor on them would put a literal <b> on the page.
      # `period` is localised rather than plain because its open end is a word: "2022 — now"
      # printed the one English word on an otherwise Ukrainian CV. A bare string still works —
      # a date range reads the same in both languages.
      fields: {
        org: :localised, title: :localised, place: :localised, period: :localised,
        note: :localised, body: :rich, case_slugs: :list
      }
    },
    stack_groups: { count: 2, fields: { label: :localised, items: :list } },
    # A strength is one sentence, so the row is that sentence rather than a hash holding it.
    strengths: { count: 4, fields: nil }
  }.freeze

  structured_json STRUCTURES

  validate :scalars_carry_both_languages

  after_save { Current.cv_rows = nil }

  class << self
    def current = Current.cv_profile || new
  end

  LOCALISED_SCALARS.each do |field|
    define_method(field) { localised(self[field]) }

    # Readers only: the writers belonged to the admin form this document no longer has. The
    # importer assigns the whole pair at once, and lib/tasks/cv.rake reads name_en to report.
    I18n.available_locales.each do |locale|
      define_method(:"#{field}_#{locale}") { pair_of(self[field])[locale.to_s] }
    end
  end

  # [key, label, href] per row, printed in order. The key and the label may each be a language
  # pair, as in Person::CV.
  def contact_rows
    self[:contact].to_a.map do |key, label, href|
      [localised(key), localised(label), href]
    end
  end

  private

  def scalars_carry_both_languages
    LOCALISED_SCALARS.each do |field|
      errors.add(field, :blank) if missing_languages(self[field]).any?
    end
  end
end
