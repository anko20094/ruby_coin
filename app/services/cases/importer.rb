# frozen_string_literal: true

# Copies config/portfolio/cases.yml into the cases table, then reads every field back and
# compares it with the source.
#
# The YAML stays in the repo as the source of truth for the initial load: every figure in it
# was read from production, git or a tracker, and the handoff forbids retyping any of them. So
# this is a copy that refuses to claim success — it returns the mismatches it found and lets
# the caller decide how loudly to fail.
class Cases::Importer < BaseService
  SOURCE = Rails.root.join('config', 'portfolio', 'cases.yml')

  Result = Struct.new(:imported, :mismatches, keyword_init: true) do
    def clean? = mismatches.empty?
  end

  def initialize(path = SOURCE)
    @path = path
  end

  def call
    imported = []
    mismatches = []

    entries.each_with_index do |entry, index|
      attributes = attributes_for(entry, index)
      record = Case.find_or_initialize_by(slug: entry['slug'])
      record.assign_attributes(attributes)
      record.save!
      record.reload

      imported << record.slug
      mismatches.concat(differences(record, attributes))
    end

    Result.new(imported: imported, mismatches: mismatches)
  end

  private

  def entries
    YAML.load_file(@path)['cases']
  end

  # The YAML nests plain/* and engineering/*; the table keeps them flat, because nothing reads
  # them as a group and a flat column is one less level to reach through in a form.
  def attributes_for(entry, index)
    {
      slug: entry['slug'],
      mark: entry['mark'],
      position: index + 1,
      own: entry['own'].present?,
      is_this_site: entry['is_this_site'].present?,
      year: entry['year'],
      sector: entry['sector'],
      status: entry['status'],
      title: entry['title'],
      tagline: entry['tagline'],
      role: entry['role'],
      scope_note: entry['scope_note'],
      plain_heading: entry.dig('plain', 'heading'),
      plain_body: entry.dig('plain', 'body'),
      engineering_heading: entry.dig('engineering', 'heading'),
      engineering_sub: entry.dig('engineering', 'sub'),
      engineering_items: entry.dig('engineering', 'items'),
      stack: entry['stack'],
      metrics: entry['metrics'],
      quality: entry['quality'],
      mine: entry['mine']
    }
  end

  def differences(record, attributes)
    attributes.filter_map do |column, expected|
      stored = record[column]
      next if stored == expected
      next if expected.nil? && stored.blank?

      "#{record.slug}.#{column}: expected #{expected.inspect}, stored #{stored.inspect}"
    end
  end
end
