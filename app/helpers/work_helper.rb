# frozen_string_literal: true

module WorkHelper
  # The case page's sections as the rail lists them, [anchor, label] — the labels are the ones
  # the sections print over themselves. The team is there only when the page draws it.
  def case_sections(team:)
    [
      ['plain', t('work.case.plain')],
      ['engineers', t('work.case.engineering')],
      (['team', t('work.case.team')] if team),
      ['contact', t('work.case.rail.contact')]
    ].compact
  end

  # A figure as the scenes draw it: the number at full size and a unit after it ("млн+", "тис.",
  # "ГБ") a size down. Anything that is not a number followed by a word stays whole: "×20",
  # "20,5 %", "#2 / 14".
  def figure(value)
    # Parsed rather than stripped: the content writes "90&nbsp;%", and only a parser turns every
    # entity back into its character.
    text = Nokogiri::HTML5.fragment(value.to_s).text.strip
    match = text.match(/\A(?<number>.*\d)(?<unit>[[:space:]]*\p{L}[\p{L}.]*\+?)\z/)
    return text unless match

    safe_join([match[:number], tag.small(match[:unit], class: 'rc-figure__unit')])
  end
end
