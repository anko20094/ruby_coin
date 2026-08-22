# frozen_string_literal: true

# The CV frame around /work: the career, the stack groups, the strengths, the contact block.
#
# The cases themselves moved into the database in W4 (see Case) so they can be edited without
# a deploy. This half is still YAML because it changes once or twice a year and always through
# a pull request, which is the cheapest review there is. CVProfile and CVBlock take it over in
# W5; until then config/portfolio/cv.yml is the source.
class Portfolio
  PATH = Rails.root.join('config', 'portfolio')
  IMAGES = Rails.root.join('app', 'assets', 'images')

  class << self
    def cv
      fetch(:cv) { YAML.load_file(PATH.join('cv.yml'))['cv'].freeze }
    end

    # The design's portrait block only renders once a real photograph is in
    # place — the prototype's generated placeholder is not shipped.
    def portrait
      fetch(:portrait) { Dir.glob(IMAGES.join('work-portrait.*')).min&.then { |path| File.basename(path) } }
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
