# frozen_string_literal: true

class FooterComponent < ViewComponent::Base
  # Three of the contact rows, in the design's order.
  CONTACT_KEYS = %w[github telegram email].freeze

  def profile
    @profile ||= Team.owner_cv
  end

  def contacts
    rows = profile.contact_rows.to_h { |key, label, href| [key, [label, href]] }
    CONTACT_KEYS.filter_map { |key| rows[key] }
  end

  # The footer is a list of places to go, and the roster is one of them: /team is deliberately
  # not in the main nav, so this and /studio are how a reader finds it.
  def links
    [
      [I18n.t('work.footer.journal'), helpers.journal_path],
      [I18n.t('work.footer.feed'), helpers.feed_path(format: :atom)],
      [I18n.t('work.footer.work'), helpers.work_path],
      [I18n.t('work.footer.team'), helpers.team_path],
      [I18n.t('work.footer.cv'), helpers.cv_path],
      # The FAQ answers the journal's readers, and nothing on the site pointed at it.
      [I18n.t('titles.faq').downcase, helpers.faq_path],
      [I18n.t('work.footer.contact'), helpers.contact_path]
    ]
  end
end
