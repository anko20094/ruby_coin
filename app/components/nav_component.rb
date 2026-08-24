# frozen_string_literal: true

# Sticky site nav: logo · sections · locale. Four sections, per the A+B decision
# (see redesign_plan.md §2) — cv is gone, it lives inside /work now.
#
# A section that is not built yet stays visible — the shape of the site is a decision, not a
# consequence of build order — but it does not navigate. It used to redirect to /work, which
# meant two items led to one page and the wrong one lit up.
class NavComponent < ViewComponent::Base
  Section = Struct.new(:key, :path, :built, keyword_init: true) do
    def label = I18n.t("work.nav.#{key}")
    def built? = built != false
  end

  # Which controller lights which section up. The home page is not one of the four sections —
  # the wordmark is the way back to it — so nothing is current there.
  SECTION_FOR_CONTROLLER = { 'journal' => :journal, 'work' => :work, 'contact' => :contact }.freeze

  # /search is the journal's search, so the journal item stays lit while a reader is on it.

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
      # /studio waits on real team data — the handoff forbids placeholder people.
      Section.new(key: :studio, path: helpers.studio_path, built: false),
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
