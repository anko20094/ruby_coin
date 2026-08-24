# frozen_string_literal: true

# One place that decides whether a view is worth recording, so the journal and the portfolio
# cannot drift apart on the question.
module ViewTracking
  def self.record(controller, subject)
    return if subject.blank?

    key = Ahoy::EventProcess.session_key_for(subject)
    return unless Ahoy::VisitsValidator.new(last_visit_for_post: controller.request.session[key]).valid?

    Ahoy::EventProcess.call(controller.ahoy, subject, controller.request)
  end
end
