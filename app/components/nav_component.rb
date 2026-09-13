# frozen_string_literal: true

# Sticky site nav: logo · sections · CV · ⌘K · locale. Four sections, and the roster is not
# one of them — /team is reached from /studio, from the foot of every case page and from ⌘K.
class NavComponent < ViewComponent::Base
  Section = Struct.new(:key, :path, keyword_init: true) do
    def label = I18n.t("work.nav.#{key}")
  end

  # Which controller lights which section up. The home page is not one of the four sections —
  # the wordmark is the way back to it — so nothing is current there.
  #
  # /search is the journal searching itself and /team is the studio's roster, so each keeps its
  # parent section lit rather than leaving the reader nowhere on the map.
  SECTION_FOR_CONTROLLER = {
    'journal' => :journal, 'work' => :work, 'contact' => :contact,
    'studio' => :studio, 'team' => :studio
  }.freeze

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

  # The section is lit for wayfinding: /search is the journal searching itself and /team is the
  # studio's roster, so each keeps its parent lit. But aria-current="page" is a statement about
  # the address, and on those two pages it would be a false one — a screen reader would announce
  # the reader as being on a page they are not on. The highlight stays; the announcement is made
  # only where it is true.
  def current_page?(section)
    helpers.current_page?(section.path)
  end

  # The CV sits apart from the sections as a chip: it is one person's page on a site that is a
  # studio's, and it is the thing a recruiter is looking for.
  def cv_current?
    helpers.controller_name == 'cv'
  end

  def locales
    I18nExtended::AVAILABLE_LOCALES
  end

  def current_locale?(locale)
    I18n.locale.to_s == locale
  end
end
