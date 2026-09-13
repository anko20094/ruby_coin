# frozen_string_literal: true

# One record from config/portfolio/people.yml: who someone is, and their CV. What they did on
# a project is a Contribution, kept in team.yml and reached through #contributions.
#
# Three states, and two of them announce themselves on the page: a full CV; a placeholder
# (`placeholder: true` — real role, invented dates, a loud banner); and no CV at all
# (`cv: null`), which renders as "not filled in yet" rather than as an invented career.
class Person
  include LocalisedJson

  # A CV nobody has dated, or one dated longer ago than this, is shown as a draft.
  STALE_AFTER = 1.year

  attr_reader :id, :short

  def initialize(attributes)
    @attributes = attributes
    @id = attributes.fetch('id')
    @short = attributes.fetch('short')
  end

  def to_param = id

  def name = localised(@attributes['name'])
  def role = localised(@attributes['role'])
  def blurb = localised(@attributes['blurb'])

  def machine? = @attributes['machine'] == true
  def placeholder? = @attributes['placeholder'] == true

  # Whose CV is the document in cv.yml — the same one /cv renders — rather than a block here.
  def owner? = @attributes['cv_file'].present?

  # As written in the file: "2026·08·18". The owner's CV is the document in cv.yml, so his date
  # comes from the imported record rather than from a second copy here — two copies of the same
  # date drift the first time one of them is updated, and this one gates the staleness chip.
  def updated
    return CVProfile.first&.figures_as_of if owner?

    @attributes['updated']
  end

  def updated_on
    Date.parse(updated.to_s.tr('·', '-'))
  rescue Date::Error
    nil
  end

  # CVProfile for the owner — nil until the row is imported, so an empty database shows the
  # same pending state a new hire does — and the YAML block for everyone else.
  def cv
    owner? ? CVProfile.first : yaml_cv
  end

  def cv? = cv.present?

  def draft? = !cv? || updated_on.nil? || updated_on < STALE_AFTER.ago.to_date

  # Optional, and rendered only when present; `detail` is optional inside it.
  def not_work
    Array(@attributes['not_work']).map do |item|
      { icon: item['icon'], label: localised(item['label']), detail: localised(item['detail']) }
    end
  end

  def contributions(order: nil) = Team.contributions_of(id, order: order)

  # Profiles a search engine may follow, for the one record whose contacts are verified. A
  # placeholder's are invented, and a fabricated profile URL in structured data is worse than
  # an absent one.
  def public_links
    return [] unless owner? && cv

    cv.contact_rows.filter_map { |_, _, href| href unless href.to_s.start_with?('mailto:') }
  end

  private

  def yaml_cv
    @yaml_cv ||= @attributes['cv']&.then { |block| Person::CV.new(block) }
  end
end
