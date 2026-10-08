# frozen_string_literal: true

# The roster is two YAML files with no schema, and editing them is the one content change that
# names real people. The rules are Team::Check's and spec/content/roster_integrity_spec.rb runs
# them too, but nobody runs the suite to answer "did I break the file". This does, in under a
# second, and it prints who is where while it is at it.
#
#   rake team:check   — the rules, and a non-zero exit if any of them is broken
#   rake team:who     — who is on the site, in what state, on which projects
namespace :team do
  desc 'Check config/portfolio/people.yml and team.yml against the rules the pages rely on'
  task check: :environment do
    result = Team::Check.call

    result.notes.each { |note| puts("  note: #{note}") }
    result.problems.each { |problem| warn(problem) }

    unless result.ok?
      warn("\n#{result.problems.size} problem#{'s' unless result.problems.one?}.")
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
