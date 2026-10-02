# frozen_string_literal: true

# Creates the cases config/portfolio/cases.yml has and the table does not, then reads every
# written field back and compares it with the source.
#
# The database is the source of truth once a case exists: /management/cases edits it, and an
# import never overwrites that edit unless asked with `force: true` (FORCE=1 in the rake task).
# The YAML is the seed — every figure in it was read from production, git or a tracker, so a
# new case is loaded from it rather than retyped.
#
# It writes in one transaction and rolls back when the read-back differs, so nothing is
# committed that was not checked; the caller decides how loudly to fail.
#
# Rows are matched on slug, which the admin can edit: a renamed case is created again beside
# the old one, and `strays` names the rows the file does not.
class Cases::Importer < BaseService
  SOURCE = Rails.root.join('config', 'portfolio', 'cases.yml')

  Result = Struct.new(:imported, :kept, :mismatches, :strays, keyword_init: true) do
    def ok? = mismatches.empty?
  end

  def initialize(path = SOURCE, force: false)
    @path = path
    @force = force
  end

  def call
    imported = []
    kept = []
    mismatches = []

    Case.transaction(requires_new: true) do
      entries.each_with_index do |entry, index|
        record = Case.find_or_initialize_by(slug: entry['slug'])
        if record.persisted? && !@force
          kept << record.slug
          next
        end

        attributes = attributes_for(entry, index)
        record.assign_attributes(attributes)
        record.save!
        record.reload

        imported << record.slug
        mismatches.concat(differences(record, attributes))
      end

      raise ActiveRecord::Rollback if mismatches.any?
    end

    imported.clear if mismatches.any?
    Result.new(imported:, kept:, mismatches:, strays: Case.where.not(slug: slugs).pluck(:slug))
  end

  private

  def entries = @entries ||= YAML.load_file(@path)['cases']

  def slugs = entries.pluck('slug')

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
