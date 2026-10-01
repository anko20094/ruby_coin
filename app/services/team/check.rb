# frozen_string_literal: true

# The rules the roster pages rely on, checked against people.yml and team.yml. The raw files are
# read too: Team builds hashes, and a hash keeps the last of two equal keys without a word.
class Team::Check < BaseService
  Result = Struct.new(:problems, :notes, keyword_init: true) do
    def ok? = problems.empty?
  end

  CREW_STRINGS = %i[name role blurb].freeze
  OPTIONAL_FOR_ALUMNI = %i[role blurb].freeze
  LOCALES = I18nExtended::AVAILABLE_LOCALES
  GITHUB_PROFILE = %r{\Ahttps://github\.com/}

  def initialize(files: Team::FILES.to_h { |name| ["#{name}.yml", Team::PATH.join("#{name}.yml")] })
    @files = files
    @problems = []
    @notes = []
  end

  def call
    duplicates
    photos

    # Everything else asks a person for their status, and one that raises would stop it.
    if known_statuses?
      languages
      cvs
      contacts
      dates
      not_work
      pages
      contributions
      solo
      placeholders
    else
      @notes << 'the other rules are skipped until every status is one of the three'
    end

    Result.new(problems: @problems, notes: @notes)
  end

  private

  def add(message) = @problems << "  #{message}"

  def duplicates
    @files.each do |name, path|
      Psych.parse_file(path).each do |node|
        next unless node.is_a?(Psych::Nodes::Mapping)

        repeated(node).each do |key, count|
          add("#{name}:#{node.start_line + 1} writes #{key.inspect} #{count} times, and only the last is read")
        end
      end
    end

    ids = YAML.load_file(@files.fetch('people.yml')).fetch('people').pluck('id')
    ids.tally.each { |id, count| add("people.yml has #{count} records with the id #{id.inspect}") if count > 1 }
  end

  def repeated(mapping)
    keys = mapping.children.each_slice(2).filter_map { |key, _value| key.value if key.is_a?(Psych::Nodes::Scalar) }

    keys.tally.select { |_key, count| count > 1 }
  end

  # A missing file is not an error until something draws it, and then it is a 500 on every page
  # that shows the person.
  def photos
    Team.everyone.each do |person|
      next if person.photo.nil? || Team::PHOTOS.join(File.basename(person.photo)).file?

      add("#{person.id} names the photo #{File.basename(person.photo)}, which is not in app/assets/images/people")
    end
  end

  # Person#status raises on an unknown value, which would abort the whole run at the first bad
  # record and report nothing else.
  def known_statuses?
    valid = Team.everyone.map do |person|
      person.status
      true
    rescue ArgumentError => e
      add(e.message)
      false
    end

    valid.all?
  end

  def languages
    Team.crew.each do |person|
      CREW_STRINGS.each { |field| both(person, field, "#{person.id}.#{field}") }
    end

    Team.alumni.each do |person|
      lost = untranslated { person.name(fallback: false) }
      add("#{person.id} has no name in #{lost.join(' and ')}") if lost.any?

      OPTIONAL_FOR_ALUMNI.each { |field| in_both_or_neither(person, field) }
    end
  end

  # The owner's CV is a CVProfile, which refuses a scalar in one language when it is saved.
  def cvs
    Team.people.each do |person|
      cv = person.cv
      next unless cv.is_a?(Person::CV)

      lost = untranslated { cv.summary(fallback: false) }
      add("#{person.id} cv.summary is missing in #{lost.join(' and ')}") if lost.any?
      add("#{person.id} cv.stacks is empty") if cv.stack_groups.blank?
      add("#{person.id} cv.experience is empty") if cv.experience.blank?
    end
  end

  # A machine has no direct channel to hand over, and a placeholder's are invented.
  def contacts
    Team.everyone.reject { |person| person.owner? || person.machine? || person.placeholder? }.each do |person|
      private_rows = Array(person.cv&.contact_rows).reject { |key, _label, href| github?(key, href) }
      next if private_rows.empty?

      add("#{person.id} publishes #{private_rows.map(&:first).join(', ')}; only a GitHub profile is public")
    end
  end

  def dates
    Team.crew.each do |person|
      next if person.updated_on

      hint = ' (it is the imported CV\'s: rake cv:import)' if person.owner?
      add("#{person.id} has no usable `updated:` date#{hint}")
    end
  end

  def not_work
    Team.people.each do |person|
      add("#{person.id} has a not-work item without an icon") if person.not_work.any? { |item| item[:icon].blank? }

      lost = untranslated { person.not_work(fallback: false).pluck(:label) }
      add("#{person.id} has a not-work label missing in #{lost.join(' and ')}") if lost.any?
    end
  end

  # A person page is drawn from the CV and the credits on projects that exist; a record with
  # neither is a link to an empty page.
  def pages
    slugs = Case.slugs

    Team.people.select(&:page?).each do |person|
      next if person.cv? || person.contributions(order: slugs).any?

      add("#{person.id} is linked but their page would be empty: no CV, and no credit on a project that exists")
    end
  end

  def contributions
    Case.slugs.each do |slug|
      Team.for_case(slug).each { |row| contribution(slug, row) }
    end

    parked
    orphans
  end

  def contribution(slug, row)
    where = "#{slug}/#{row.person_id}"

    %i[role period].each do |field|
      lost = untranslated { row.public_send(field, fallback: false) }
      add("#{where} has no #{field} in #{lost.join(' and ')}") if lost.any?
    end

    lines = in_locales { row.did(fallback: false) }
    add("#{where} is #{lines.map(&:size).uniq.join('/')} lines, not two") unless lines.map(&:size) == [2, 2]
    add("#{where} has an untranslated line") if lines.flatten.any?(&:blank?)
  end

  # Not an error. A hidden person's rows are meant to stay in the file — that is what makes
  # hiding someone reversible — but it is worth saying out loud which work is parked.
  def parked
    hidden = Team.everyone.select(&:hidden?).map(&:id)
    return if hidden.empty?

    Team.credited_slugs.each do |slug|
      Team.rows_for(slug).each do |row|
        @notes << "#{slug}/#{row.person_id} is parked — the person is hidden" if hidden.include?(row.person_id)
      end
    end
  end

  def orphans
    known = Team.everyone.map(&:id)

    Team.credited_slugs.each do |slug|
      add("#{slug} is credited but is not a case") unless Case.slugs.include?(slug)

      Team.rows_for(slug).each do |row|
        add("#{slug}/#{row.person_id} names nobody in people.yml") unless known.include?(row.person_id)
      end
    end

    Case.slugs.each { |slug| add("#{slug} has nobody on it") if Team.for_case(slug).empty? }
  end

  def solo
    Case.slugs.each do |slug|
      team = Team.for_case(slug)
      next if team.empty?

      add("#{slug} claims solo with #{team.size} credited") if team.any?(&:solo?) && team.size > 1
      add("#{slug} has one contributor and does not say solo") if team.one? && !team.first.solo?
      add("#{slug} is solo and does not say whose team the others were on") if team.one? && unsaid?(team.first)
    end
  end

  # The launch gate, stated in people.yml's own header.
  def placeholders
    names = Team.people.select(&:placeholder?).map(&:id)
    return if names.empty?

    @notes << "#{names.size} placeholder CV#{'s' unless names.one?} — #{names.join(', ')}"
  end

  def both(person, field, where)
    lost = untranslated { person.public_send(field, fallback: false) }
    return add("#{where} is missing in #{lost.join(' and ')}") if lost.any?

    add("#{where} is the same string in both languages") if in_locales { person.public_send(field) }.uniq.one?
  end

  def in_both_or_neither(person, field)
    lost = untranslated { person.public_send(field, fallback: false) }
    return if lost.empty? || lost.size == LOCALES.size

    add("#{person.id}.#{field} is written in #{(LOCALES - lost).join(' and ')} only")
  end

  def unsaid?(contribution) = untranslated { contribution.outside(fallback: false) }.any?

  def github?(key, href) = key == 'github' && href.to_s.match?(GITHUB_PROFILE)

  # The readers fall back to Ukrainian, so the blocks passed here ask for `fallback: false`:
  # otherwise a missing English line reads as the Ukrainian one and is never reported.
  def untranslated(&)
    LOCALES.select do |locale|
      strings = I18n.with_locale(locale, &)

      strings.is_a?(Array) ? strings.any?(&:blank?) : strings.blank?
    end
  end

  def in_locales(&) = LOCALES.map { |locale| I18n.with_locale(locale, &) }
end
