# frozen_string_literal: true

# The roster and who did what on which project: config/portfolio/people.yml and team.yml,
# read as one thing.
#
# YAML rather than tables, by decision (handoff §6, TECH-STACK). Six people who change once a
# quarter are edited through a pull request, where a diff is the right review. A CV belongs
# to the person and a contribution belongs to the project; keeping them in two files is what
# stops a person's page and a case page from describing the same work in two sentences.
#
# Development re-reads the files on every call so an edit shows on refresh; everywhere else
# they are parsed once per process.
module Team
  PATH = Rails.root.join('config', 'portfolio')
  FILES = %w[people team].freeze

  class << self
    def people = roster.values

    def person(id) = roster[id.to_s]

    def person!(id)
      person(id) || raise(ActiveRecord::RecordNotFound, "no person #{id.inspect} in people.yml")
    end

    # The one whose CV is cv.yml — the person /cv is about.
    def owner = people.find(&:owner?)

    # Who worked on a project, in file order.
    def for_case(slug) = contributions.fetch(slug.to_s, [])

    # Every project the contributions file names. Read by the content specs, which check that
    # none of them has left the portfolio behind a dead row.
    def credited_slugs = contributions.keys

    # Every project one person touched. `order` is the projects' own display order, which is
    # the cases' and not this file's — and it is also the list of projects that still exist,
    # so one that has left the portfolio takes its contributions off the person page with it.
    def contributions_of(id, order: nil)
      rows = contributions.values.flatten.select { |contribution| contribution.person_id == id.to_s }
      return rows if order.nil?

      rows.select { |contribution| order.include?(contribution.slug) }
          .sort_by { |contribution| order.index(contribution.slug) }
    end

    # Changes when either file does, so a page cached on the roster expires with it.
    def version
      cached(:version) { Digest::SHA256.hexdigest(FILES.map { |name| PATH.join("#{name}.yml").read }.join) }
    end

    def reload!
      @cache = nil
    end

    private

    def roster
      cached(:roster) do
        YAML.load_file(PATH.join('people.yml')).fetch('people').to_h do |attributes|
          [attributes.fetch('id'), Person.new(attributes)]
        end
      end
    end

    def contributions
      cached(:contributions) do
        YAML.load_file(PATH.join('team.yml')).fetch('contributions').to_h do |slug, rows|
          [slug, Array(rows).map { |row| Contribution.new(slug, row) }]
        end
      end
    end

    # Parsed once per process, except in development, where the files are the thing being
    # edited and an edit has to show on refresh.
    #
    # Development keys the cache on the files' mtimes rather than skipping it: every reader here
    # is called once per person, per card and per monogram, so "re-read every time" meant
    # twenty-seven parses of a 25 KB file to draw one page. Two stat calls answer the same
    # question.
    def cached(key)
      store = (@cache ||= {})
      stamp = Rails.env.development? ? mtimes : :boot

      store.clear unless store[:stamp] == stamp
      store[:stamp] = stamp
      store[key] ||= yield
    end

    def mtimes
      FILES.map { |name| PATH.join("#{name}.yml").mtime }
    end
  end
end
