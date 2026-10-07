# frozen_string_literal: true

class WorkController < ApplicationController
  def index
    @cases = Case.ordered.to_a
    # Each card shows who built the project. Read once for the whole page rather than once per
    # card, so the roster is parsed a single time.
    @team_by_slug = @cases.to_h { |kase| [kase.slug, Team.for_case(kase.slug)] }

    cache_publicly(@cases)
  end

  def show
    # One load of the seven rows answers all three questions the page asks of the list: which
    # case this is, what is either side of it, and how many there are.
    slug = params.expect(:slug)
    cases = Case.ordered.to_a
    @case = cases.find { |kase| kase.slug == slug } or raise ActiveRecord::RecordNotFound
    @previous_case, @next_case = @case.neighbours(cases)
    @total = cases.size
    # The stone keeps the shade its card has on /work and the home page.
    @tone = cases.index(@case)
    @team = Team.for_case(@case.slug)
    topics = Cases::Topics.new(cases)
    @topic_posts = topics.posts_for(@case).includes(:tags, :translations).to_a
    @shared_tags = @topic_posts.to_h { |post| [post.id, topics.shared_tags(post, @case)] }
    @lead_tag = topics.lead_tag(@case, @topic_posts)

    # Which cases actually get opened is the one number that should decide the order of
    # /work. Recorded before the freshness check,
    # so a reader coming back to a page their browser has cached still counts as a reader.
    ViewTracking.record(self, @case)

    cache_publicly(cases, @topic_posts, @topic_posts.flat_map(&:tags))
  end
end
