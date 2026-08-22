# frozen_string_literal: true

# The front door. Everything on it is real content: the hero reads from the CV, the latest
# entry from the journal, the three cards from the cases.
class HomeController < ApplicationController
  # The home page is on the redesigned theme. /search is the last public page that is not, and
  # the handoff's IA does not cover it, so it keeps the old layout until it does.
  layout -> { action_name == 'search' ? 'application' : 'theme' }

  RECENT_CASES = 3

  # The old front page was the article stream, so its pagination and tag filter lived on these
  # query strings. They are gone for good now that / is the home page — 301, and carry what
  # they meant across to /journal. (redesign_plan.md §4.3)
  LEGACY_STREAM_PARAMS = %i[page tag_ids order].freeze

  before_action :redirect_legacy_stream_params, only: :index

  def index
    @profile = CVProfile.current
    @latest = Post.main.first || Post.active.first
    @cases = Case.ordered.limit(RECENT_CASES)
    @entries_count = Post.active.count
  end

  def search
    @posts = Posts::Filter.call(active_collection, { order: 'RANDOM()' }).limit(Post::LIMIT_COUNT)
    @results = Posts::Search.call(search_params)
    @results = Posts::Filter.call(@results, params) if @results.present?
  end

  private

  def redirect_legacy_stream_params
    return if LEGACY_STREAM_PARAMS.none? { |key| params[key].present? }

    redirect_to journal_path(
      tag_id: Array(params[:tag_ids]).compact_blank.first,
      order: params[:order].presence,
      page: params[:page].presence
    ), status: :moved_permanently
  end

  def search_params
    params.permit(:query, :search_in)
  end

  def active_collection
    Post.active
  end
end
