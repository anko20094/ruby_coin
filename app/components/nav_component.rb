# frozen_string_literal: true

# Sticky site nav: logo · sections · locale. Four sections, per the A+B decision
# (see redesign_plan.md §2) — cv is gone, it lives inside /work now.
class NavComponent < ViewComponent::Base
  Section = Struct.new(:key, :path, :keyword_init) do
    def label = I18n.t("work.nav.#{key}")
  end

  # Which controller lights which section up. Journal has no controller of its
  # own yet — the article stream still lives on home#index until W3.
  SECTION_FOR_CONTROLLER = { 'home' => :journal, 'work' => :work }.freeze

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
      Section.new(key: :journal, path: helpers.root_path),
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
