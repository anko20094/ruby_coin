# frozen_string_literal: true

# Sticky site nav: logo · sections · locale. Four sections, per the A+B decision
# (see redesign_plan.md §2) — cv is gone, it lives inside /work now.
class NavComponent < ViewComponent::Base
  Section = Struct.new(:key, :path, :keyword_init) do
    def label = I18n.t("work.nav.#{key}")
  end

  # Which controller lights which section up. home#index is still the old article
  # stream until W7, so it lights journal up too.
  SECTION_FOR_CONTROLLER = { 'journal' => :journal, 'home' => :journal, 'work' => :work }.freeze

  # Passed in where the caller knows; derived from the controller otherwise, so
  # the layout stays dumb.
  def initialize(current: nil)
    @current = current
    super()
  end

  def current_section
    @current || SECTION_FOR_CONTROLLER[helpers.controller_name]
  end

  def sections
    [
      Section.new(key: :journal, path: helpers.journal_path),
      Section.new(key: :work, path: helpers.work_path),
      Section.new(key: :studio, path: helpers.studio_path),
      Section.new(key: :contact, path: helpers.contact_path)
    ]
  end

  def current?(section)
    current_section == section.key
  end

  def locales
    I18nExtended::AVAILABLE_LOCALES
  end

  def current_locale?(locale)
    I18n.locale.to_s == locale
  end
end
