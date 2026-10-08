# frozen_string_literal: true

class TrackTagComponentPreview < ViewComponent::Preview
  # The ruby tone opens the "in plain words" track.
  # @param label text
  def ruby(label: 'in plain words')
    render(TrackTagComponent.new(label: label, tone: :ruby))
  end

  # The soft tone opens "for engineers", and labels the index sections.
  # @param label text
  def soft(label: 'for engineers')
    render(TrackTagComponent.new(label: label, tone: :soft))
  end

  # On the work index the label is the section heading itself.
  def as_heading
    render(TrackTagComponent.new(label: 'the projects', tone: :ruby, heading: :h2))
  end
end
