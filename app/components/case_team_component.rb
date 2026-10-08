# frozen_string_literal: true

class CaseTeamComponent < ViewComponent::Base
  delegate :rich, to: :helpers

  attr_reader :team

  def initialize(team:, slug:)
    @team = team
    @slug = slug

    super()
  end

  # One person who did the whole thing reads as a claim; a grid holding one card reads as an
  # unfinished page.
  def solo = helpers.solo_contribution(team)

  def label
    return t('work.case.team') if solo

    "#{t('work.case.team')} · #{t('counts.contributors', count: team.size)}"
  end

  def person_link(contribution) = helpers.person_path(id: contribution.person, from: @slug)
end
