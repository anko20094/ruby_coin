# frozen_string_literal: true

# Who built it, at the foot of a case. Each card leads to that person's page with the project
# as ?from=, so the page they land on opens on this contribution.
#
# The card is not one big <a>: its link is the name (or "open CV" on a solo card) and a
# stretched ::after makes the whole card the target, so the link's name is a name and not
# every line of the card read in one breath.
class CaseTeamComponent < ViewComponent::Base
  delegate :rich, to: :helpers

  def initialize(team:, slug:)
    @team = team
    @slug = slug
    super()
  end

  attr_reader :team

  # One person who did the whole thing reads as a claim; a grid holding one card reads as an
  # unfinished page.
  def solo = helpers.solo_contribution(team)

  def label
    return t('work.case.team') if solo

    "#{t('work.case.team')} · #{t('counts.contributors', count: team.size)}"
  end

  def person_link(contribution) = helpers.person_path(id: contribution.person, from: @slug)
end
