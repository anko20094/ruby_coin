# frozen_string_literal: true

module Ahoy
  # One view, recorded once per session per subject.
  #
  # It used to know only about posts. Cases were invisible — and "which cases do recruiters
  # actually open" is the question the handoff says should decide what sits at the top of
  # /work (§9a). Same throttle, same shape, one more subject.
  class EventProcess < BaseService
    EVENTS = { 'Post' => 'Viewed Post', 'Case' => 'Viewed Case' }.freeze

    def initialize(ahoy, subject, request)
      @ahoy = ahoy
      @subject = subject
      @request = request
    end

    def call
      @ahoy.visit
      @ahoy.track(event_name, title: @subject.title, slug: @subject.slug, **identifier)
      @request.session[session_key] = Time.zone.now.to_i
    end

    # The key a controller checks before deciding whether this is a repeat view.
    def self.session_key_for(subject)
      "last_visit_#{subject.class.name.downcase}_#{subject.id}"
    end

    private

    def event_name
      EVENTS.fetch(@subject.class.name) { "Viewed #{@subject.class.name}" }
    end

    # post_id is kept under its old name because two years of rows already use it and
    # Post.best reads it.
    def identifier
      @subject.is_a?(Post) ? { post_id: @subject.id } : { case_id: @subject.id }
    end

    def session_key
      self.class.session_key_for(@subject)
    end
  end
end
