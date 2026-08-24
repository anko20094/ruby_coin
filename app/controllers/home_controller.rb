# frozen_string_literal: true

# The front door. Everything on it is real content: the hero reads from the CV, the latest
# entry from the journal, the three cards from the cases.
class HomeController < ApplicationController
  layout 'theme'

  RECENT_CASES = 3

  # The old front page was the article stream, so its pagination and tag filter lived on these
  # query strings. They are gone for good now that / is the home page — 301, and carry what
  # they meant across to /journal. (redesign_plan.md §4.3)
  LEGACY_STREAM_PARAMS = %i[page tag_ids order].freeze

  before_action :redirect_legacy_stream_params, only: :index

  def index
    @profile = CVProfile.current
    @latest = Post.main.includes(:tags, :user, :translations).first ||
              Post.active.includes(:tags, :user, :translations).first
    @cases = Case.ordered.limit(RECENT_CASES)
    @entries_count = Post.active.count
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
end
