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
end
