# frozen_string_literal: true

# Content that carries both languages inside JSONB, as {"en" => …, "uk" => …}.
#
# Used by Case and by the YAML readers (Person, Person::CV, Contribution). The portfolio YAML
# stores every translated string this way, so the database keeps the same shape rather than a
# translations table; Mobility is for Post only.
module LocalisedJson
  extend ActiveSupport::Concern

  class_methods do
    # For a model whose JSONB columns hold one string per language: a reader in the current
    # locale, <field>_<locale> readers and writers for the admin form, and the editorial
    # rule — never one language alone. A bare string satisfies it: some fields are the
    # same characters in both languages ("2023—2026").
    def localised_scalars(fields)
      fields.each do |field|
        define_method(field) { localised(self[field]) }

        I18n.available_locales.each do |locale|
          define_method(:"#{field}_#{locale}") { pair_of(self[field])[locale.to_s] }
          define_method(:"#{field}_#{locale}=") do |value|
            self[field] = pair_of(self[field]).merge(locale.to_s => value)
          end
        end
      end

      validate { fields.each { |field| errors.add(field, :blank) if missing_languages(self[field]).any? } }
    end
  end

  private

  # A plain string passes through: some fields are proper nouns that read the same in both
  # languages, and the YAML writes those without a language pair.
  def localised(value, fallback: true)
    return value unless value.is_a?(Hash)

    value[I18n.locale.to_s].presence || (value[I18n.default_locale.to_s] if fallback)
  end

  def localised_pair(values)
    I18n.available_locales.to_h { |locale| [locale.to_s, values[locale.to_s]] }
  end

  # The language pair a value stands for: a plain string is the same text in every language.
  def pair_of(value)
    case value
    when Hash then value
    when String then I18n.available_locales.to_h { |locale| [locale.to_s, value] }
    else {}
    end
  end

  def missing_languages(value)
    pair = pair_of(value)

    I18n.available_locales.reject { |locale| pair[locale.to_s].present? }
  end
end
