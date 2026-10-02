# frozen_string_literal: true

module Profile
  # The CV blocks, read from config/portfolio/cv.yml (Team.owner_cv) and the roster.
  class CVBlocksPreview < ViewComponent::Preview
    # @label Summary
    def summary
      render(Profile::SummaryComponent.new(profile: cv))
    end

    # @label Career, with the cases it names
    def career
      render(Profile::CareerComponent.new(profile: cv, cases_by_slug: ::Case.ordered.index_by(&:slug)))
    end

    # @label Stack and strengths
    def stack
      render(Profile::StackComponent.new(profile: cv))
    end

    # @label Contact panel
    def contact_panel
      render(Profile::ContactPanelComponent.new(profile: cv))
    end

    # @label What someone did (dense)
    def did
      render(Profile::DidComponent.new(lines: ['Built the importer, <b>end to end</b>.', 'Kept the figures honest.'],
                                       dense: true))
    end

    # @label Not written yet
    def pending
      render(Profile::PendingComponent.new)
    end

    private

    def cv = Team.owner_cv
  end
end
