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
  # Fields that are one string per language.
  LOCALISED_SCALARS = %i[
    title tagline role plain_heading engineering_heading engineering_sub scope_note
  ].freeze

  # Structured content, declared once so the model, the admin form and the importer agree on
  # the shape. `count` is what the design draws; the schema does not enforce it.
  #
  #   :plain     — one value in one language, the same in both (a number, a stack name)
  #   :localised — {"en" => …, "uk" => …}
  STRUCTURES = {
    metrics: { count: 4, fields: { value: :plain, label: :localised } },
    quality: { count: 4, fields: { value: :plain, label: :localised } },
    engineering_items: { count: 6, fields: { title: :localised, body: :localised } },
    plain_body: { count: 3, fields: nil },
    mine: { count: 4, fields: nil }
  }.freeze

  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9-]+\z/ }
  validates :mark, :position, presence: true
  validate :scalars_carry_both_languages

  scope :ordered, -> { order(:position) }

  class << self
    def slugs
      ordered.pluck(:slug)
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

  # Structured readers hand the views ready-to-print hashes with symbol keys, so a template
  # never picks a language or reaches into raw JSON.
  STRUCTURES.each do |field, spec|
    define_method(field) do
      items = self[field].to_a
      next items.map { |item| localised(item) } if spec[:fields].nil?

      items.map do |item|
        spec[:fields].to_h do |key, kind|
          [key, kind == :localised ? localised(item[key.to_s]) : item[key.to_s]]
        end
      end
    end
  end

  # Writers for the admin form. A form sends a structured field as an index-keyed hash
  # (case[metrics_rows][0][value]), and the controller has to permit that subtree wholesale;
  # normalising here means only declared keys ever reach the column, so a stray field in the
  # request cannot end up stored.
  STRUCTURES.each_key do |field|
    define_method(:"#{field}_rows") { self[field].to_a }

    define_method(:"#{field}_rows=") do |submitted|
      self[field] = normalised_rows(field, submitted)
    end
  end

  # The stack is a plain list, so the form edits it as one item per line.
  def stack_list
    self[:stack].to_a.join("\n")
  end

  def stack_list=(value)
    self[:stack] = value.to_s.split("\n").map(&:strip).compact_blank
  end

  # The list wraps: the last case's next is the first.
  def neighbours
    slugs = self.class.slugs
    index = slugs.index(slug)
    return [self, self] if index.nil? || slugs.one?

    [self.class.find_by!(slug: slugs[index - 1]), self.class.find_by!(slug: slugs[(index + 1) % slugs.size])]
  end

  def number
    self.class.slugs.index(slug).to_i + 1
  end

  private

  def normalised_rows(field, submitted)
    spec = STRUCTURES.fetch(field.to_sym)
    rows = submitted.to_h.sort_by { |index, _| index.to_i }.map { |_, row| row.to_h }

    rows.filter_map { |row| normalised_row(spec, row) }
  end

  # A row is dropped when the author has left it empty, which is how a case ends up with three
  # metrics instead of four without needing a delete button.
  def normalised_row(spec, row)
    if spec[:fields].nil?
      pair = localised_pair(row)
      return pair.values.any?(&:present?) ? pair : nil
    end

    kept = spec[:fields].to_h do |key, kind|
      value = row[key.to_s]
      [key.to_s, kind == :localised ? localised_pair(value.to_h) : value]
    end

    kept.values.any? { |value| filled?(value) } ? kept : nil
  end

  def filled?(value)
    value.is_a?(Hash) ? value.values.any?(&:present?) : value.present?
  end

  def localised_pair(values)
    I18n.available_locales.to_h { |locale| [locale.to_s, values[locale.to_s]] }
  end

  def localised(value)
    return value unless value.is_a?(Hash)

    value[I18n.locale.to_s].presence || value[I18n.default_locale.to_s]
  end

  # The handoff's editorial rule: never one language alone.
  def scalars_carry_both_languages
    LOCALISED_SCALARS.each do |field|
      values = self[field].to_h
      missing = I18n.available_locales.reject { |locale| values[locale.to_s].present? }
      errors.add(field, :blank) if missing.any?
    end
  end
end
