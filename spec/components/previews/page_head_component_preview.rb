# frozen_string_literal: true

class PageHeadComponentPreview < ViewComponent::Preview
  # A section page opens on this: the title on a dark scene, the anchor gem in its rings.
  # @param title text
  # @param lede textarea
  def default(title: 'Journal', lede: 'Notes from the work: stories from projects, snippets, things that broke us.')
    render(PageHeadComponent.new(title:, lede:, uid: 'preview-head'))
  end

  # With the pill: a ruby badge and a line.
  def with_eyebrow
    render(PageHeadComponent.new(title: 'Projects', uid: 'preview-head-pill', badge: '7', eyebrow: 'projects, in order',
                                 lede: 'In the order we would put them in front of you.'))
  end
end
