# frozen_string_literal: true

# One project on /work. Seven of them today, ordered, each with two registers: the plain-words
# track and the engineering track.
#
# Content was YAML (config/portfolio/cases.yml) until W4 and is still imported from it — see
# lib/tasks/deployment/*_import_cases.rake. The YAML stays as the import source, so a verified
# figure is never retyped by hand.
#
# Every translated field is JSONB holding {"en" => …, "uk" => …}. Readers return the current
# locale; the raw hash is always available as self[:field], which is what the admin form edits
# through the generated <field>_<locale> accessors.
class Case < ApplicationRecord
  include StructuredJson

  # Fields that are one string per language, and which of them the pages print as markup.
  #
  # year, sector and status are here rather than plain columns because they read as prose:
  # "2022—present", "publishing · education" and "built from zero · 19 contributors" printed
  # English into the middle of a Ukrainian case page. They are printed escaped, so they get a
  # plain input and not an editor.
  RICH_SCALARS = %i[title tagline role plain_heading engineering_heading engineering_sub scope_note].freeze
  PLAIN_SCALARS = %i[year sector status].freeze
  LOCALISED_SCALARS = (RICH_SCALARS + PLAIN_SCALARS).freeze

  # Structured content, declared once so the model, the admin form and the importer agree on
  # the shape. `count` is what the design draws; the schema does not enforce it.
  #
  # Every localised field here is :rich, because app/views/work/show.html.slim prints all of
  # them through ProseHelper#rich — see StructuredJson for what the kinds mean.
  # A figure is localised too: Ukrainian groups thousands with a space and takes a comma for
  # the decimal, so "89,030" beside a label reading "86 395 унікальних" said 89.03.
  STRUCTURES = {
    metrics: { count: 4, fields: { value: :localised, label: :rich } },
    quality: { count: 4, fields: { value: :localised, label: :rich } },
    engineering_items: { count: 6, fields: { title: :rich, body: :rich } },
    plain_body: { count: 3, fields: nil, row: :rich },
    mine: { count: 4, fields: nil, row: :rich }
  }.freeze

  structured_json STRUCTURES

  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9-]+\z/ }
  validates :mark, presence: true
  validates :position, numericality: { only_integer: true, greater_than: 0, less_than: 1_000_000 }
  validate :scalars_carry_both_languages
  validate :rows_carry_both_languages
  validate :slug_kept_while_named, on: :update
  before_destroy :refuse_while_named, prepend: true

  scope :ordered, -> { order(:position, :id) }

  class << self
    def slugs
      ordered.pluck(:slug)
    end

    # The year the oldest project here started — what the home page means by "shipping since".
    # Taken from the content rather than typed into the copy, so it cannot drift from the work.
    def first_year
      pluck(:year).filter_map { |year| year.to_s[/\d{4}/] }.min
    end
  end

  LOCALISED_SCALARS.each do |field|
    define_method(field) { localised(self[field]) }

    I18n.available_locales.each do |locale|
      define_method(:"#{field}_#{locale}") { pair_of(self[field])[locale.to_s] }
      define_method(:"#{field}_#{locale}=") do |value|
        self[field] = pair_of(self[field]).merge(locale.to_s => value)
      end
    end
  end

  # The stack is a plain list, so the form edits it as one item per line.
  def stack_list
    self[:stack].to_a.join("\n")
  end

  def stack_list=(value)
    self[:stack] = value.to_s.split("\n").map(&:strip).compact_blank
  end

  # Where this case sits in the list, and the two either side of it — the list wraps, so the
  # last case's next is the first.
  #
  # Both take the ordered list rather than fetching one, because the caller usually has it:
  # drawing a case page used to cost `Case.slugs`, two `find_by!(slug:)` and a second
  # `Case.slugs` for the position — four queries against a seven-row table to render one
  # pager.
  def position_in(list = self.class.ordered)
    list.index { |kase| kase.slug == slug }
  end

  def number(list = self.class.ordered)
    position_in(list).to_i + 1
  end

  def neighbours(list = self.class.ordered.to_a)
    index = position_in(list)
    return [self, self] if index.nil? || list.one?

    [list[index - 1], list[(index + 1) % list.size]]
  end

  private

  # The handoff's editorial rule: never one language alone. A bare string satisfies it — some of
  # these fields are the same characters in both languages ("2023—2026"), and LocalisedJson
  # hands a plain string to whichever locale asks.
  def scalars_carry_both_languages
    LOCALISED_SCALARS.each do |field|
      errors.add(field, :blank) if missing_languages(self[field]).any?
    end
  end

  # team.yml credits and the owner's CV entries name a case by its slug, and nothing follows a
  # rename or a delete: the credits and links simply stop resolving.
  def slug_kept_while_named
    errors.add(:slug, :named_elsewhere) if slug_changed? && named_elsewhere?(slug_was)
  end

  def refuse_while_named
    return unless named_elsewhere?(slug)

    errors.add(:slug, :named_elsewhere)
    throw :abort
  end

  def named_elsewhere?(name)
    Team.credited_slugs.include?(name) ||
      CVProfile.current.experience_rows.any? { |row| Array(row['case_slugs']).include?(name) }
  end

  def rows_carry_both_languages
    STRUCTURES.each do |field, spec|
      errors.add(field, :one_language_only) if self[field].to_a.any? { |row| half_translated?(spec, row) }
    end
  end
end
