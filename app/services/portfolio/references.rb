# frozen_string_literal: true

module Portfolio::References
  module_function

  def slugs
    Team.credited_slugs | cv_slugs
  end

  def named?(slug) = slugs.include?(slug.to_s)

  # [person, slug] for every career entry that names a case.
  def cv_entries
    Team.everyone.flat_map do |person|
      Array(person.cv&.experience).flat_map { |entry| entry[:case_slugs].map { |slug| [person, slug] } }
    end
  end

  def cv_slugs = cv_entries.map(&:last).uniq
end
