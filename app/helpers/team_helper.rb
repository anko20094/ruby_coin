# frozen_string_literal: true

module TeamHelper
  # What a /work card shows before it starts counting: three stack chips and four faces. Both
  # are the design's budget rather than the content's — the case page carries the rest.
  STACK_CHIPS = 3
  FACES = 4

  # The contribution to print as a statement instead of a grid. A team block holding one lonely
  # card reads as an unfinished page; "Solo — the whole stack" reads as a claim, which is what
  # it is. This is the whole reason `solo` exists in team.yml.
  def solo_contribution(team)
    team.first if team.one? && team.first.solo?
  end

  # "N contributors", or "solo" where one person did the whole thing. Not "people": one of the
  # six on the roster is a machine.
  def team_size_label(team)
    solo_contribution(team) ? t('work.index.solo') : t('counts.contributors', count: team.size)
  end
end
