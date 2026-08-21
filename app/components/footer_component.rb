# frozen_string_literal: true

# Site footer: identity · section links · contacts. Every value is real and
# comes from cv.yml — the prototype's footer carried placeholder identity
# ("RubyCoin LLC", github.com/ronico-ua) which must never ship.
class FooterComponent < ViewComponent::Base
  include PortfolioHelper

  # Three of the contact rows, in the design's order.
  CONTACT_KEYS = %w[github telegram email].freeze

  delegate :cv, to: :Portfolio

  def contacts
    rows = cv['contact'].to_h { |key, value, href| [key, [value, href]] }
    CONTACT_KEYS.filter_map { |key| rows[key] }
  end

  def links
    [
      [I18n.t('work.footer.journal'), helpers.root_path],
      [I18n.t('work.footer.work'), helpers.work_path],
      [I18n.t('work.footer.studio'), helpers.studio_path],
      [I18n.t('work.footer.contact'), helpers.contact_path]
    ]
  end
end
