# frozen_string_literal: true

class CaseTeamComponentPreview < ViewComponent::Preview
  # @label A team
  def team
    render(CaseTeamComponent.new(team: Team.for_case('dna'), slug: 'dna'))
  end

  # @label Solo
  def solo
    render(CaseTeamComponent.new(team: Team.for_case('intelligence'), slug: 'intelligence'))
  end
end
