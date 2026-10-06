# frozen_string_literal: true

class Person::CV
  include LocalisedJson

  SCALARS = %w[role years summary location languages education].freeze

  def initialize(block)
    @block = block
  end

  SCALARS.each do |field|
    define_method(field) { |fallback: true| localised(@block[field], fallback: fallback) }
  end

  # cv.yml keeps the name as two keys, because it predates the language pairs.
  def name(fallback: true)
    value = @block['nameUk'] ? { 'en' => @block['name'], 'uk' => @block['nameUk'] } : @block['name']

    localised(value, fallback: fallback)
  end

  # The date the CV's figures were read on: "2026·08·18".
  def figures_as_of = @block['updated']

  # [key, label, href] per row, printed in order. The key and the label may each be a language
  # pair: "email" reads the same in both, "runs in" does not.
  def contact_rows
    Array(@block['contact']).map do |key, label, href|
      [localised(key), localised(label), href]
    end
  end

  def experience
    Array(@block['experience']).map do |entry|
      {
        org: localised(entry['org']), title: localised(entry['title']), place: localised(entry['place']),
        period: localised(entry['period']), note: localised(entry['note']), body: localised(entry['body']),
        case_slugs: Array(entry['cases'])
      }
    end
  end

  # A stack item is usually a proper noun and reads the same in both languages; where it is
  # prose ("merge rights", "discovery calls") it carries a pair, and a bare string still passes
  # straight through.
  def stack_groups
    Array(@block['stacks']).map do |group|
      { label: localised(group['label']), items: Array(group['items']).map { |item| localised(item) } }
    end
  end

  def strengths = Array(@block['strengths']).map { |strength| localised(strength) }
end
