# frozen_string_literal: true

# The roster is two YAML files with no schema, and editing them is the one content change that
# names real people. spec/requests/roster_integrity_spec.rb is the real gate, but it is fifteen
# examples inside a suite of six hundred, and nobody runs the suite to answer "did I break the
# file". This does, in under a second, and it prints who is where while it is at it.
#
#   rake team:check   — the rules, and a non-zero exit if any of them is broken
#   rake team:who     — who is on the site, in what state, on which projects
namespace :team do
  desc 'Check config/portfolio/people.yml and team.yml against the rules the pages rely on'
  task check: :environment do
    problems = TeamCheck.new.run

    problems.each { |problem| warn(problem) }

    if problems.any?
      warn("\n#{problems.size} problem#{'s' unless problems.one?}.")
      exit 1
    end

    puts "roster is consistent: #{Team.crew.size} on the crew, #{Team.alumni.size} alumni, " \
         "#{Team.everyone.count(&:hidden?)} hidden."
  end

  desc 'Print who is on the site, in what state, and on which projects'
  task who: :environment do
    slugs = Case.slugs
    width = Team.everyone.map { |person| person.id.length }.max

    Team.everyone.each do |person|
      on = Team.contributions_of(person.id, order: slugs).map(&:slug)
      state = person.hidden? ? 'hidden' : person.status
      page = person.page? ? '' : ' · name only'

      puts "#{person.id.ljust(width)}  #{state.ljust(6)}#{page.ljust(12)} #{on.join(', ')}"
    end
  end
end

# Not a model: nothing else needs it, and it exists to be read top to bottom by whoever is about
# to edit the file.
class TeamCheck
  CREW_STRINGS = %i[name role blurb].freeze

  def initialize
    @problems = []
  end

  def run
    statuses
    languages
    pages
    contributions
    solo
    placeholders

    @problems
  end

  private

  def add(message) = @problems << "  #{message}"

  # Person#status raises on an unknown value, which would abort the whole task at the first bad
  # record and report nothing else. Reading the raw value keeps every problem in one run.
  def statuses
    Team.everyone.each do |person|
      person.status
    rescue ArgumentError => e
      add(e.message)
    end
  end

  def languages
    Team.crew.each do |person|
      CREW_STRINGS.each { |field| both(person, field, "#{person.id}.#{field}") }
    end

    Team.alumni.each do |person|
      add("#{person.id} has no name") if in_locales { person.name }.any?(&:blank?)
    end
  end

  # A link has to lead somewhere. A record with no CV and no contribution is a name, and the
  # studio page draws it as one — so this only reports the reverse, which would be a dead link.
  def pages
    Team.people.each do |person|
      next if person.page?

      add("#{person.id} has a CV but no page") if person.cv?
      add("#{person.id} is credited but has no page") if person.contributions.any?
    end
  end

  def contributions
    Case.slugs.each do |slug|
      Team.for_case(slug).each { |row| contribution(slug, row) }
    end

    parked
    orphans
  end

  def contribution(slug, row)
    where = "#{slug}/#{row.person_id}"

    add("#{where} has no role") if row.role.blank?
    add("#{where} has no period") if row.period.blank?

    lines = in_locales { row.did }
    add("#{where} is #{lines.map(&:size).uniq.join('/')} lines, not two") unless lines.map(&:size) == [2, 2]
    add("#{where} has an untranslated line") if lines.flatten.any?(&:blank?)
  end

  # Not an error. A hidden person's rows are meant to stay in the file — that is what makes
  # hiding someone reversible — but it is worth saying out loud which work is parked.
  def parked
    hidden = Team.everyone.select(&:hidden?).map(&:id)
    return if hidden.empty?

    Team.credited_slugs.each do |slug|
      Team.rows_for(slug).each do |row|
        puts "  note: #{slug}/#{row.person_id} is parked — the person is hidden" if hidden.include?(row.person_id)
      end
    end
  end

  def orphans
    known = Team.everyone.map(&:id)

    Team.credited_slugs.each do |slug|
      add("#{slug} is credited but is not a case") unless Case.slugs.include?(slug)

      Team.rows_for(slug).each do |row|
        add("#{slug}/#{row.person_id} names nobody in people.yml") unless known.include?(row.person_id)
      end
    end

    Case.slugs.each { |slug| add("#{slug} has nobody on it") if Team.for_case(slug).empty? }
  end

  def solo
    Case.slugs.each do |slug|
      team = Team.for_case(slug)
      next if team.empty?

      add("#{slug} claims solo with #{team.size} credited") if team.any?(&:solo?) && team.size > 1
      add("#{slug} has one contributor and does not say solo") if team.one? && !team.first.solo?
      add("#{slug} is solo and does not say whose team the others were on") if team.one? && team.first.outside.blank?
    end
  end

  # The launch gate, stated in people.yml's own header.
  def placeholders
    names = Team.people.select(&:placeholder?).map(&:id)
    return if names.empty?

    puts "  note: #{names.size} placeholder CV#{'s' unless names.one?} — #{names.join(', ')}"
  end

  def both(person, field, where)
    values = in_locales { person.public_send(field) }

    return add("#{where} is missing a language") if values.any?(&:blank?)

    add("#{where} is the same string in both languages") if values.uniq.one?
  end

  def in_locales(&) = I18nExtended::AVAILABLE_LOCALES.map { |locale| I18n.with_locale(locale, &) }
end
