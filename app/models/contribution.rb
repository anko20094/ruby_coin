# frozen_string_literal: true

# What one person did on one project — a row of config/portfolio/team.yml. It belongs to the
# project: a person page is composed by asking for their rows, so a contribution is written
# once and cannot drift between the two pages.
class Contribution
  include LocalisedJson

  attr_reader :slug, :person_id

  def initialize(slug, row)
    @slug = slug
    @row = row
    @person_id = row.fetch('person')
  end

  def person = Team.person!(person_id)
  def period(fallback: true) = localised(@row['period'], fallback: fallback)
  def role(fallback: true) = localised(@row['role'], fallback: fallback)
  def did(fallback: true) = Array(@row['did']).map { |line| localised(line, fallback: fallback) }
  def solo? = @row['solo'] == true
  def outside(fallback: true) = localised(@row['outside'], fallback: fallback)
end
