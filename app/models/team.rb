# frozen_string_literal: true

# The roster and who did what on which project: config/portfolio/people.yml, team.yml and the
# owner's CV in cv.yml, read as one thing.
#
# YAML rather than tables, by decision (docs/decisions.md). People who change once a
# quarter are edited through a pull request, where a diff is the right review. A CV belongs
# to the person and a contribution belongs to the project; keeping them in two files is what
# stops a person's page and a case page from describing the same work in two sentences.
#
# Development re-reads the files on every call so an edit shows on refresh; everywhere else
# they are parsed once per process.
module Team
  PATH = Rails.root.join('config', 'portfolio')
  FILES = %w[people team cv].freeze
  PHOTOS = Rails.root.join('app', 'assets', 'images', 'people')

  class << self
    # Every record in the file, hidden ones included. The check task and the integrity spec are
    # the callers: to prove someone is off the site you first have to be able to see them.
    def everyone = roster.values

    # Everyone the site shows: the crew and the alumni, in file order. `hidden` is not "gone",
    # it is "not on the site", so it is filtered here rather than deleted from the file.
    def people = everyone.reject(&:hidden?)

    # The crew — who the studio is today. This is what the roster pages, the home strip and the
    # search palette mean by "us".
    def crew = people.select(&:active?)

    # Named, and no longer here. They keep whatever credits team.yml gives them, which is the
    # whole reason this is a status on a record rather than a second list of strings: a name
    # cannot fall out of step with itself.
    def alumni = people.select(&:alumni?)

    def person(id) = roster[id.to_s]

    # Raises for a hidden record as well as a missing one: the person page must 404 while
    # someone is off the site, and every caller here wants exactly that.
    def person!(id)
      found = person(id)

      return found if found && !found.hidden?

      raise(ActiveRecord::RecordNotFound, "no visible person #{id.inspect} in people.yml")
    end

    # The one whose CV is cv.yml — the person /cv is about.
    def owner = people.find(&:owner?)

    # cv.yml: the CV /cv, the owner's page, the footer and the share cards print.
    def owner_cv
      cached(:owner_cv) { Person::CV.new(YAML.load_file(PATH.join('cv.yml')).fetch('cv')) }
    end

    # Every row the file holds for a project, hidden people included. The check task is the
    # caller: to report that a row is parked you first have to be able to see it.
    def rows_for(slug) = contributions[slug.to_s] || []

    # Who worked on a project, in file order. A hidden person's row stays in team.yml and stops
    # being rendered — which is what makes hiding someone reversible.
    def for_case(slug) = rows_for(slug).reject { |row| person(row.person_id)&.hidden? }

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

    # Changes when anything a roster page draws does, so a page cached on it expires with it.
    #
    # The photographs are in here as well as the files. A new face under the same filename
    # leaves both YAMLs untouched, so hashing only those left the ETag identical: every browser
    # holding the page kept serving it, pointing at the digested URL of the photograph that had
    # been replaced. The face changed on disk and nowhere else.
    def version
      cached(:version) { Digest::SHA256.hexdigest(sources.join) }
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

    def sources
      FILES.map { |name| PATH.join("#{name}.yml").read } +
        photo_files.map { |file| Digest::SHA256.file(file).then(&:hexdigest) }
    end

    # Dir.glob sorts, which matters: the digest has to be the same on every machine.
    def photo_files = Dir.glob(PHOTOS.join('*'))

    # Development re-reads on a changed file, and a replaced photograph is a changed file.
    def mtimes
      (FILES.map { |name| PATH.join("#{name}.yml") } + photo_files).map { |file| File.mtime(file) }
    end
  end
end
