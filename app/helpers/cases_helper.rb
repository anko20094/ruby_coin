# frozen_string_literal: true

module CasesHelper
  # How many rows of a structured field the admin form draws: what the design expects, what
  # the case actually holds, and one spare so a row can be added without a button.
  def case_rows_count(kase, field)
    spec = Case::STRUCTURES.fetch(field)

    [spec[:count], kase.public_send(:"#{field}_rows").size].max + 1
  end

  def case_row_value(kase, field, index, *keys)
    row = kase.public_send(:"#{field}_rows")[index]

    keys.reduce(row) { |value, key| value.is_a?(Hash) ? value[key.to_s] : nil }
  end

  # Prose gets a textarea, figures and labels get a single line.
  def case_field_tag(name, value, long: false)
    if long
      text_area_tag name, value, rows: 3, class: 'standart-input'
    else
      text_field_tag name, value, class: 'standart-input'
    end
  end
end
