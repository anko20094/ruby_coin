# frozen_string_literal: true

class MonogramComponentPreview < ViewComponent::Preview
  # Every person on the roster at the sidebar size.
  def roster
    render_with_template(locals: { people: Team.people })
  end

  # The machine on the roster carries a CI flag across the bottom.
  # @param size number
  def machine(size: 120)
    render(MonogramComponent.new(initials: 'C', seed: 'claude', machine: true, size: size))
  end
end
