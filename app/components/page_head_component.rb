# frozen_string_literal: true

class PageHeadComponent < ViewComponent::Base
  attr_reader :title, :lede, :eyebrow, :badge, :uid, :mark

  # uid names the anchor gem's SVG ids; the eyebrow is the pill's line, the badge its ruby lead.
  # Anything passed as content sits under the lede, inside the scene: a search field, an identity
  # line with a print button.
  def initialize(title:, uid:, lede: nil, eyebrow: nil, badge: nil, mark: '·')
    @title = title
    @uid = uid
    @lede = lede
    @eyebrow = eyebrow
    @badge = badge
    @mark = mark

    super()
  end

  def eyebrow? = eyebrow.present? || badge.present?
end
