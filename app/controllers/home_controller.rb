# frozen_string_literal: true

# The front door. Everything on it is real content: the hero reads from the CV, the latest
# entry from the journal, the three cards from the cases.
class HomeController < ApplicationController
  RECENT_CASES = 3

  # The old front page was the article stream, so its pagination and tag filter lived on these
  # query strings (page, tag_ids, order). They are gone for good now that / is the home page —
  # 301, and carry what they meant across to /journal.
  LEGACY_PER_PAGE = 6

  # Ahead of the locale redirect: an old address is one permanent hop, not a 302 and then a 301.
  prepend_before_action :redirect_legacy_stream_params, only: :index

  def index
    readable = Post.translated_in(I18n.locale).includes(:tags, :user, :translations)
    @latest = readable.main.first || readable.active.ordered.first
    # Seven rows: one load answers the cards, the count and the year.
    cases = Case.ordered.to_a
    @cases = cases.first(RECENT_CASES)
    @people = Team.crew
    @projects_count = cases.size
    @first_year = Case.first_year(cases)

    cache_publicly(cases, @latest, @latest&.tags, @latest&.user)
  end

  private

  # The locale-less address is the one that was indexed, and the old stream answered it in the
  # default language whatever the browser asked for.
  def redirect_legacy_stream_params
    query = legacy_stream_query
    return if query.empty?

    locale = request.path_parameters[:locale] || I18n.default_locale
    redirect_to journal_path(locale:, **query), status: :moved_permanently
  end

  # Only what the old stream could have sent: a nested value is somebody's probe, not a link.
  def legacy_stream_query
    stream = params.permit(:order, :page, :tag_ids, tag_ids: [])

    {
      tag_id: Array.wrap(stream[:tag_ids]).grep(/\A\d+\z/).first,
      order: stream[:order].presence_in(Post::ORDER_TYPES),
      page: legacy_page(stream[:page])
    }.compact
  end

  def legacy_page(page)
    return unless page&.match?(/\A\d+\z/)

    ((page.to_i - 1).clamp(0..) * LEGACY_PER_PAGE / JournalController::PER_PAGE) + 1
  end
end
