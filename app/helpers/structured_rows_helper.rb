# frozen_string_literal: true

module StructuredRowsHelper
  # The row index inside the <template> the add button clones. Swapped for a fresh number by
  # structure_rows_controller.js; it has to be something that cannot occur in a real name.
  ROW_INDEX = '__INDEX__'

  # Which row a field belongs to. The three travel together everywhere, so they travel as one.
  RowPath = Struct.new(:scope, :field, :index)

  # The rows the form draws: what the record holds, and — for a record that holds none yet —
  # as many blank ones as the design expects, so a new one starts in the right shape.
  # STRUCTURES#count is a starting point and a hint beside the heading, never a limit.
  def structure_rows(record, field)
    rows = record.public_send(:"#{field}_rows")

    rows.presence || Array.new(record.class::STRUCTURES.fetch(field.to_sym).fetch(:count)) { {} }
  end

  # One field inside a row.
  #
  # `keys` is the path into it: [:label, :en] for one language of a localised sub-field,
  # [:period] for a plain one, [:en] for a row that *is* the string. `index` is the row's
  # position, or ROW_INDEX for the row inside the <template>. `locale` is the language the
  # field holds, for the editor to set on its document.
  #
  # The name is assembled from two data attributes as well as written out, because
  # structure_rows_controller.js renumbers every row after an add, a remove or a move: the
  # server reads the rows in index order, so the index has to follow what is on the screen.
  def structure_row_field(path, keys:, kind:, value: nil, label: nil, locale: nil)
    prefix = "#{path.scope}[#{path.field}_rows]"
    suffix = keys.map { |key| "[#{key}]" }.join

    render 'management/shared/structure_field',
           name: "#{prefix}[#{path.index}]#{suffix}", label: label, kind: kind,
           value: kind == :list ? Array(value).join("\n") : value,
           # gsub, not parameterize: parameterize would turn ROW_INDEX into "index", every
           # cloned row would carry the same id, and TinyMCE would refuse a second editor on it.
           id: "#{path.scope}_#{path.field}_#{path.index}_#{keys.join('_')}".gsub(/[^A-Za-z0-9_]/, '_'),
           prefix: prefix, suffix: suffix, lang: locale
  end

  # Where in a row a value lives, for the rows that already exist.
  #
  # A plain string stands in for both languages. Some fields are proper nouns — an employer's
  # name — and the YAML wrote those once rather than as a pair, so asking for one language of
  # `"myHomeIQ"` has to answer "myHomeIQ" and not nothing. Without this the form drew both
  # boxes empty and saving wrote the emptiness back: the name was gone, silently, on a form
  # nobody had typed in.
  def structure_row_value(row, *keys)
    keys.reduce(row) do |value, key|
      case value
      when Hash then value[key.to_s]
      when String then value
      end
    end
  end
end
