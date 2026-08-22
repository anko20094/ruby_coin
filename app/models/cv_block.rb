# frozen_string_literal: true

# One entry in an ordered list on /work: a career entry, a stack group, or a strength.
#
# All three live in one table because they are the same kind of thing — a small piece of
# localised content with a position — and none of them is ever queried on its own fields.
# If they grow their own behaviour, single-table inheritance is the next step.
class CVBlock < ApplicationRecord
  include LocalisedJson

  KINDS = %w[experience stack_group strength].freeze

  # What each kind keeps in its payload. `localised` keys hold {"en" => …, "uk" => …} or a
  # plain string when the value reads the same in both languages (an employer's name).
  SHAPES = {
    'experience' => { localised: %i[org title place note body], plain: %i[period], required: %i[org title] },
    'stack_group' => { localised: %i[label], plain: %i[items], required: %i[label items] },
    'strength' => { localised: %i[text], plain: [], required: %i[text] }
  }.freeze

  PAYLOAD_KEYS = SHAPES.values.flat_map { |shape| shape[:localised] + shape[:plain] }.uniq.freeze

  validates :kind, inclusion: { in: KINDS }
  validates :position, presence: true
  validate :payload_carries_what_the_kind_needs

  scope :ordered, -> { order(:position, :id) }
  scope :experience, -> { where(kind: 'experience').ordered }
  scope :stack_groups, -> { where(kind: 'stack_group').ordered }
  scope :strengths, -> { where(kind: 'strength').ordered }

  # One reader per payload key. A key that belongs to another kind simply reads nil, which is
  # also true of the optional ones — not every career entry has a note or a body.
  PAYLOAD_KEYS.each do |key|
    define_method(key) do
      raw = payload.to_h[key.to_s]
      localised?(key) ? localised(raw) : raw
    end

    # A field the YAML wrote as a plain string reads the same in both languages, so the form
    # shows that string in both boxes — and editing one of them promotes the field to a pair
    # without losing the other language.
    I18n.available_locales.each do |locale|
      define_method(:"#{key}_#{locale}") do
        raw = payload.to_h[key.to_s]
        raw.is_a?(Hash) ? raw[locale.to_s] : raw
      end

      define_method(:"#{key}_#{locale}=") do |value|
        current = payload.to_h
        self.payload = current.merge(key.to_s => pair_for(current[key.to_s]).merge(locale.to_s => value))
      end
    end
  end

  # Stack items are a plain list, edited one per line.
  def items_list
    Array(payload.to_h['items']).join("\n")
  end

  def items_list=(value)
    self.payload = payload.to_h.merge('items' => value.to_s.split("\n").map(&:strip).compact_blank)
  end

  def period=(value)
    self.payload = payload.to_h.merge('period' => value)
  end

  def case_slugs_list
    Array(self[:case_slugs]).join(', ')
  end

  def case_slugs_list=(value)
    self[:case_slugs] = value.to_s.split(',').map(&:strip).compact_blank
  end

  # The cases a career entry points at, in the order the list holds them, skipping any slug
  # whose case has since been deleted.
  def cases
    Case.where(slug: Array(self[:case_slugs])).index_by(&:slug).values_at(*Array(self[:case_slugs])).compact
  end

  private

  # Whatever the field holds now, as a language pair.
  def pair_for(existing)
    case existing
    when Hash then existing
    when String then I18n.available_locales.to_h { |locale| [locale.to_s, existing] }
    else {}
    end
  end

  def localised?(key)
    SHAPES.fetch(kind, { localised: [] })[:localised].include?(key.to_sym)
  end

  def payload_carries_what_the_kind_needs
    shape = SHAPES[kind]
    return if shape.nil?

    shape[:required].each do |key|
      errors.add(:payload, :blank) if payload.to_h[key.to_s].blank?
    end
  end
end
