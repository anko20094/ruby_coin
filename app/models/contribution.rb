# frozen_string_literal: true

# What one person did on one project — a row of config/portfolio/team.yml. It belongs to the
# project: a person page is composed by asking for their rows, so a contribution is written
# once and cannot drift between the two pages.
class Contribution
  include LocalisedJson

  attr_reader :slug, :person_id, :period

  def initialize(slug, row)
    @slug = slug
    @row = row
    @person_id = row.fetch('person')
    @period = row['period']
  end

  def person = Team.person!(person_id)
  def role = localised(@row['role'])
  def did = Array(@row['did']).map { |line| localised(line) }
  def solo? = @row['solo'] == true
  def outside = localised(@row['outside'])
end
