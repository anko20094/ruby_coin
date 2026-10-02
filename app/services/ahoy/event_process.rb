# frozen_string_literal: true

module Ahoy
  # One view, recorded once per session per subject.
  #
  # Cases are counted as well as posts: which cases people actually open is what should decide
  # the order of /work.
  class EventProcess < BaseService
    EVENTS = { 'Post' => 'Viewed Post', 'Case' => 'Viewed Case' }.freeze
    SESSION_KEY_PREFIX = 'last_visit_'
    SESSION_WINDOW = 24.hours
    MAX_TRACKED = 30

    def initialize(ahoy, subject, request)
      @ahoy = ahoy
      @subject = subject
      @request = request
    end

    def call
      @ahoy.visit
      @ahoy.track(event_name, title: @subject.title, slug: @subject.slug, **identifier)
      remember_view
    end

    # The key a controller checks before deciding whether this is a repeat view.
    def self.session_key_for(subject)
      "#{SESSION_KEY_PREFIX}#{subject.class.name.downcase}_#{subject.id}"
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

    def remember_view
      prune_session
      @request.session[session_key] = Time.zone.now.to_i
    end

    # The session is a 4 KB cookie: keep the views still inside the throttle window, newest first.
    def prune_session
      session = @request.session
      views = session.keys.select { |key| key.to_s.start_with?(SESSION_KEY_PREFIX) }
      current = views.select { |key| session[key].to_i > SESSION_WINDOW.ago.to_i }
      kept = current.max_by(MAX_TRACKED - 1) { |key| session[key].to_i }

      (views - kept).each { |key| session.delete(key) }
    end
  end
end
