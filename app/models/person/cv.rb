# frozen_string_literal: true

# A CV written in people.yml, with the same face as CVProfile so one set of partials draws
# both.
class Person::CV
  include LocalisedJson

  SCALARS = %w[role years summary location languages education].freeze

  def initialize(block)
    @block = block
  end

  SCALARS.each do |field|
    define_method(field) { localised(@block[field]) }
  end

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
