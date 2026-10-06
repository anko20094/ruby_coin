# frozen_string_literal: true

module StructuredJson
  extend ActiveSupport::Concern
  include LocalisedJson

  # The two kinds that hold a language pair. They differ only in what the admin draws for them.
  LOCALISED_KINDS = %i[localised rich].freeze

  class_methods do
    # Readers hand the views ready-to-print hashes with symbol keys, so a template never picks
    # a language or reaches into raw JSON. Writers take what a form posts — an index-keyed hash
    # — and keep only the declared keys, so a stray field in the request cannot reach a column.
    def structured_json(structures)
      structures.each do |field, spec|
        define_method(field) { structured_read(field, spec) }
        define_method(:"#{field}_rows") { self[field].to_a }
        define_method(:"#{field}_rows=") { |submitted| self[field] = normalised_rows(structures, field, submitted) }
      end
    end
  end

  private

  def structured_read(field, spec)
    items = self[field].to_a
    return items.map { |item| localised(item) } if spec[:fields].nil?

    items.map do |item|
      spec[:fields].to_h { |key, kind| [key, structured_value(kind, item.to_h[key.to_s])] }
    end
  end

  def structured_value(kind, raw)
    case kind
    when *LOCALISED_KINDS then localised(raw)
    when :list then Array(raw).map { |item| localised(item) }
    else raw
    end
  end

  def normalised_rows(structures, field, submitted)
    spec = structures.fetch(field.to_sym)
    rows = submitted.to_h.sort_by { |index, _| index.to_i }.map { |_, row| row.to_h }

    rows.filter_map { |row| normalised_row(spec, row) }
  end

  # A row is dropped when the author has left it empty, which is how a list ends up with three
  # entries instead of four without needing a delete button to have been pressed.
  def normalised_row(spec, row)
    if spec[:fields].nil?
      pair = localised_pair(row)
      return pair.values.any?(&:present?) ? pair : nil
    end

    kept = spec[:fields].to_h { |key, kind| [key.to_s, normalised_value(kind, row[key.to_s])] }
    kept.values.any? { |value| filled?(value) } ? kept : nil
  end

  # A list arrives from a form as one item per line and from the importer as an array already.
  def normalised_value(kind, value)
    case kind
    when *LOCALISED_KINDS then localised_pair(value.to_h)
    when :list then value.is_a?(Array) ? value.map { |item| item.to_s.strip } : value.to_s.split("\n").map(&:strip)
    else value
    end.then { |result| result.is_a?(Array) ? result.compact_blank : result }
  end

  # One language filled in and the other left empty: the row a form can post half-translated.
  def half_translated?(spec, row)
    pairs = spec[:fields].nil? ? [row] : localised_values(spec, row)

    pairs.any? do |pair|
      missing = missing_languages(pair)
      missing.any? && missing.size < I18n.available_locales.size
    end
  end

  def localised_values(spec, row)
    return [] unless row.is_a?(Hash)

    spec[:fields].filter_map { |key, kind| row[key.to_s] if LOCALISED_KINDS.include?(kind) }
  end

  def filled?(value)
    case value
    when Hash then value.values.any?(&:present?)
    when Array then value.any?(&:present?)
    else value.present?
    end
  end
end
