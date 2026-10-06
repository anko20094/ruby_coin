# frozen_string_literal: true

module ViewTracking
  def self.record(controller, subject)
    return if subject.blank? || controller.current_user&.staff_member?

    key = Ahoy::EventProcess.session_key_for(subject)
    return unless Ahoy::VisitsValidator.new(last_visit_for_post: controller.request.session[key]).valid?

    Ahoy::EventProcess.call(controller.ahoy, subject, controller.request)
  end
end
