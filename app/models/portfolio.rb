# frozen_string_literal: true

# Content for /work — the seven cases plus the CV frame around them.
#
# It lives in config/portfolio/*.yml rather than in the database: it changes a
# few times a year and always through a pull request, so YAML gives review in
# the diff and needs no migration, admin UI or seeding step.
class Portfolio
  PATH = Rails.root.join('config', 'portfolio')
  IMAGES = Rails.root.join('app', 'assets', 'images')

  class << self
    def cases
      fetch(:cases) { YAML.load_file(PATH.join('cases.yml'))['cases'].freeze }
    end

    def cv
      fetch(:cv) { YAML.load_file(PATH.join('cv.yml'))['cv'].freeze }
    end

    # The design's portrait block only renders once a real photograph is in
    # place — the prototype's generated placeholder is not shipped.
    def portrait
      fetch(:portrait) { Dir.glob(IMAGES.join('work-portrait.*')).min&.then { |path| File.basename(path) } }
    end

    def case!(slug)
      cases.find { |kase| kase['slug'] == slug } || raise(ActiveRecord::RecordNotFound)
    end

    def find(slug)
      cases.find { |kase| kase['slug'] == slug }
    end

    def position(slug)
      cases.index { |kase| kase['slug'] == slug }
    end

    # The list wraps: case 07's next is case 01.
    def neighbours(slug)
      index = position(slug)
      [cases[index - 1], cases[(index + 1) % cases.size]]
    end

    private

    # Memoised in production, re-read in development so editing the YAML shows
    # up on reload.
    def fetch(key)
      return yield if Rails.env.development?

      @fetched ||= {}
      # fetch, not ||=, so a legitimately absent portrait is cached too.
      @fetched.fetch(key) { @fetched[key] = yield }
    end
  end
end
