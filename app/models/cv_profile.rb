# frozen_string_literal: true

# The CV: who this is, the summary, the contact column, and the three ordered lists /work
# prints — career, stack groups, strengths.
#
# All of it is one row. The lists used to be a `cv_blocks` table with its own model,
# controller, policy and CRUD screens, which made a CV of ten lines behave like a collection
# you browse: changing two words was a page navigation, and reordering was typing a number
# into a field. It is one document, edited whole a few times a year, so it is stored and
# edited as one. See redesign_plan.md §11.16.
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
      # `body` is the only one /work prints through ProseHelper#rich; the rest are escaped,
      # so an editor on them would put a literal <b> on the page.
      fields: {
        org: :localised, title: :localised, place: :localised, period: :plain,
        note: :localised, body: :rich, case_slugs: :list
      }
    },
    stack_groups: { count: 2, fields: { label: :localised, items: :list } },
    # A strength is one sentence, so the row is that sentence rather than a hash holding it.
    strengths: { count: 4, fields: nil }
  }.freeze

  structured_json STRUCTURES

  validate :scalars_carry_both_languages

  class << self
    def current
      first || new
    end
  end

  LOCALISED_SCALARS.each do |field|
    define_method(field) { localised(self[field]) }

    I18n.available_locales.each do |locale|
      define_method(:"#{field}_#{locale}") { self[field].to_h[locale.to_s] }
      define_method(:"#{field}_#{locale}=") do |value|
        self[field] = self[field].to_h.merge(locale.to_s => value)
      end
    end
  end

  CONTACT_KEYS = %w[key label href].freeze

  # [key, label, href] per row, printed in order.
  def contact_rows
    self[:contact].to_a.map { |row| Array(row) }
  end

  def contact_rows=(submitted)
    rows = submitted.to_h.sort_by { |index, _| index.to_i }.map { |_, row| row.to_h }

    self[:contact] = rows.filter_map do |row|
      values = CONTACT_KEYS.map { |key| row[key].to_s.strip }
      values.any?(&:present?) ? values : nil
    end
  end

  # The portrait only renders once a real photograph is in place; the prototype's generated
  # placeholder is deliberately not shipped. It is a repo asset rather than an upload because
  # there is exactly one of it and it changes about as often as the CV does.
  def portrait
    Rails.root.glob('app/assets/images/work-portrait.*').min&.then { |path| File.basename(path) }
  end

  private

  def scalars_carry_both_languages
    LOCALISED_SCALARS.each do |field|
      values = self[field].to_h
      errors.add(field, :blank) if I18n.available_locales.any? { |locale| values[locale.to_s].blank? }
    end
  end
end
