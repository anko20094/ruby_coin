# frozen_string_literal: true

# Copies config/portfolio/cv.yml into cv_profiles and cv_blocks, then reads it back and
# compares, the same way Cases::Importer does. The YAML came from a PDF CV by hand once; it is
# not going to be retyped a second time.
class CV::Importer < BaseService
  SOURCE = Rails.root.join('config', 'portfolio', 'cv.yml')

  Result = Struct.new(:profile, :blocks, :mismatches, keyword_init: true) do
    def clean? = mismatches.empty?
  end

  def initialize(path = SOURCE)
    @path = path
  end

  def call
    source = YAML.load_file(@path)['cv']

    profile = import_profile(source)
    blocks = import_blocks(source)

    Result.new(profile: profile, blocks: blocks, mismatches: @mismatches.to_a)
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
      updated_on: source['updated']
    }

    profile = CVProfile.first || CVProfile.new
    profile.assign_attributes(attributes)
    profile.save!
    profile.reload

    record_mismatches(profile, 'profile', attributes)
    profile
  end

  def import_blocks(source)
    blocks = []
    blocks.concat(import_kind('experience', source['experience']) { |e, i| experience_attributes(e, i) })
    blocks.concat(import_kind('stack_group', source['stacks']) { |e, i| stack_attributes(e, i) })
    blocks.concat(import_kind('strength', source['strengths']) { |e, i| strength_attributes(e, i) })
    blocks
  end

  # Blocks have no natural key in the YAML, so the position within its kind is the identity.
  # Re-importing therefore overwrites in place instead of piling up duplicates.
  def import_kind(kind, entries)
    Array(entries).each_with_index.map do |entry, index|
      attributes = yield(entry, index)
      block = CVBlock.find_or_initialize_by(kind: kind, position: attributes[:position])
      block.assign_attributes(attributes)
      block.save!
      block.reload

      record_mismatches(block, "#{kind}[#{index}]", attributes)
      block
    end
  end

  def experience_attributes(entry, index)
    {
      kind: 'experience',
      position: index + 1,
      payload: entry.slice('period', 'org', 'title', 'place', 'note', 'body'),
      case_slugs: Array(entry['cases'])
    }
  end

  def stack_attributes(entry, index)
    { kind: 'stack_group', position: index + 1, payload: entry.slice('label', 'items'), case_slugs: [] }
  end

  # A strength is a bare {en, uk} in the YAML; wrapping it under one key keeps every block's
  # payload shaped the same way.
  def strength_attributes(entry, index)
    { kind: 'strength', position: index + 1, payload: { 'text' => entry }, case_slugs: [] }
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
