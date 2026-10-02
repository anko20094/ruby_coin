# frozen_string_literal: true

class FlashComponentPreview < ViewComponent::Preview
  # @label Notice
  def notice
    render(FlashComponent.new(flash: { notice: 'The post was saved.' }))
  end

  # @label Alert
  def alert
    render(FlashComponent.new(flash: { alert: 'You are not allowed to do that.' }))
  end

  # @label Both tones at once
  def both
    render(FlashComponent.new(flash: { notice: 'Signed in.', alert: 'Your session expired.' }))
  end
end
