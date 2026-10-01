# frozen_string_literal: true

# One record from config/portfolio/people.yml: who someone is, and their CV. What they did on
# a project is a Contribution, kept in team.yml and reached through #contributions.
#
# `status:` is how someone joins and leaves without their work leaving with them:
#
#   active (default) — on the crew, on every page
#   alumni           — off the crew, still credited on the cases they worked on
#   hidden           — off the site entirely; the record and its contributions stay in the file
#
# The point of `hidden` is that taking someone down is one word rather than a deletion: their
# rows in team.yml stay put, the diff says what happened, and putting them back is the same
# word again. The point of `alumni` is that leaving a studio does not unwrite the code.
#
# The CV has three states of its own, and two announce themselves on the page: a full CV; a
# placeholder (`placeholder: true` — real role, invented dates, a loud banner); and no CV at
# all (`cv: null`), which renders as "not filled in yet" rather than as an invented career.
class Person
  include LocalisedJson

  # A CV nobody has dated, or one dated longer ago than this, is shown as a draft.
  STALE_AFTER = 1.year

  STATUSES = %w[active alumni hidden].freeze

  attr_reader :id

  def initialize(attributes)
    @attributes = attributes
    @id = attributes.fetch('id')
  end

  def to_param = id

  def name(fallback: true) = localised(@attributes['name'], fallback: fallback)
  def role(fallback: true) = localised(@attributes['role'], fallback: fallback)
  def blurb(fallback: true) = localised(@attributes['blurb'], fallback: fallback)

  # Only a crew card draws a monogram, and a name-only alumnus has no initials to draw one from.
  def short = @attributes['short']

  # A file under app/assets/images/people. Absent means initials, which is a finished state and
  # not a missing one — see MonogramComponent.
  def photo
    name = @attributes['photo']

    "people/#{name}" if name.present?
  end

  def status
    value = @attributes['status'].presence || 'active'

    STATUSES.include?(value) ? value : raise(ArgumentError, "#{id}: unknown status #{value.inspect}")
  end

  def active? = status == 'active'
  def alumni? = status == 'alumni'
  def hidden? = status == 'hidden'

  # Whether this record is worth opening. An alumnus credited on a project has something to
  # show and the case page links at them; one who is only a name has nothing behind the link,
  # and a link that leads nowhere is worse than a name that does not pretend to.
  def page? = !hidden? && (cv? || contributions.any?)

  def machine? = @attributes['machine'] == true
  def placeholder? = @attributes['placeholder'] == true

  # Whose CV is the document in cv.yml — the same one /cv renders — rather than a block here.
  def owner? = @attributes['cv_file'].present?

  # As written in the file: "2026·08·18". The owner's CV is the document in cv.yml, so his date
  # comes from the imported record rather than from a second copy here — two copies of the same
  # date drift the first time one of them is updated, and this one gates the staleness chip.
  def updated
    return Current.cv_profile&.figures_as_of if owner?

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
    owner? ? Current.cv_profile : yaml_cv
  end

  def cv? = cv.present?

  def draft? = !cv? || updated_on.nil? || updated_on < STALE_AFTER.ago.to_date

  # Optional, and rendered only when present; `detail` is optional inside it.
  def not_work(fallback: true)
    Array(@attributes['not_work']).map do |item|
      {
        icon: item['icon'], label: localised(item['label'], fallback: fallback),
        detail: localised(item['detail'], fallback: fallback)
      }
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
