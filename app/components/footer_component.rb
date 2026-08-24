# frozen_string_literal: true

# Site footer: identity · section links · contacts. Every value is real and comes from the CV
# — the prototype's footer carried placeholder identity ("RubyCoin LLC", github.com/ronico-ua)
# which must never ship.
class FooterComponent < ViewComponent::Base
  # Three of the contact rows, in the design's order.
  CONTACT_KEYS = %w[github telegram email].freeze

  def profile
    @profile ||= CVProfile.current
  end

  def contacts
    rows = profile.contact_rows.to_h { |key, label, href| [key, [label, href]] }
    CONTACT_KEYS.filter_map { |key| rows[key] }
  end

  # The studio row is left out entirely rather than shown greyed: the footer is a list of places
  # to go, and there is nowhere to go yet.
  #
  # The first row used to be labelled "rss" and point at the home page — the design's wording
  # kept, the feed never built. There is a feed now, so the label is true; the journal keeps
  # its own row beside it.
  def links
    [
      [I18n.t('work.footer.journal'), helpers.journal_path],
      [I18n.t('work.footer.feed'), helpers.feed_path(format: :atom)],
      [I18n.t('work.footer.work'), helpers.work_path],
      [I18n.t('work.footer.contact'), helpers.contact_path]
    ]
  end
end
