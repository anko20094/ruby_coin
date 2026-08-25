# frozen_string_literal: true

# Copies config/portfolio/cv.yml into cv_profiles, then reads it back and compares, the same
# way Cases::Importer does. The YAML came from a PDF CV by hand once; it is not going to be
# retyped a second time.
#
# The three lists used to import into a cv_blocks table, one row each. They are structured
# fields on the profile now, so the whole CV is one write and one comparison.
class CV::Importer < BaseService
  SOURCE = Rails.root.join('config', 'portfolio', 'cv.yml')

  Result = Struct.new(:profile, :mismatches, keyword_init: true) do
    def clean? = mismatches.empty?
  end

  # The YAML calls a career entry's linked cases `cases`; the column is `case_slugs`, because
  # that is what they are — slugs, resolved against Case when the page is drawn.
  EXPERIENCE_KEYS = %w[org title place period note body].freeze

  def initialize(path = SOURCE)
    @path = path
  end

  def call
    source = YAML.load_file(@path)['cv']

    Result.new(profile: import_profile(source), mismatches: @mismatches.to_a)
  end

  private

  def import_profile(source)
    attributes = {
      # The YAML keeps the name as two keys because it predates the language pairs; the table
      # has no reason to repeat that.
      name: { 'en' => source['name'], 'uk' => source['nameUk'] },
      role: source['role'],
      years: source['years'],
      summary: source['summary'],
      location: source['location'],
      languages: source['languages'],
      education: source['education'],
      contact: source['contact'],
      figures_as_of: source['updated'],
      experience: experience_rows(source['experience']),
      stack_groups: stack_rows(source['stacks']),
      # A strength is a bare {en, uk} in the YAML and the row is that value, so it copies over
      # untouched.
      strengths: Array(source['strengths'])
    }

    profile = CVProfile.first || CVProfile.new
    profile.assign_attributes(attributes)
    profile.save!
    profile.reload

    record_mismatches(profile, 'profile', attributes)
    profile
  end

  def experience_rows(entries)
    Array(entries).map do |entry|
      entry.slice(*EXPERIENCE_KEYS).merge('case_slugs' => Array(entry['cases']))
    end
  end

  def stack_rows(entries)
    Array(entries).map { |entry| entry.slice('label', 'items') }
  end

  def record_mismatches(record, label, attributes)
    @mismatches ||= []

    attributes.each do |column, expected|
      stored = record[column]
      next if stored == expected
      next if expected.nil? && stored.blank?

      @mismatches << "#{label}.#{column}: expected #{expected.inspect}, stored #{stored.inspect}"
    end
  end
end
