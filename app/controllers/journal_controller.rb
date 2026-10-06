# frozen_string_literal: true

class JournalController < ApplicationController
  PER_PAGE = 20

  # Which half of a post to look in. 'all' first, because it is the default.
  SEARCH_FIELDS = %w[all title description].freeze

  # One entry per Post::ORDER_TYPES, so adding an ordering means adding it in both places or
  # the fetch falls back rather than raising.
  ORDERS = {
    'new' => -> { Post.active.ordered },
    'oldest' => -> { Post.oldest },
    'best' => -> { Post.best }
  }.freeze
  GROUPED_ORDERS = %w[new oldest].freeze
  # More than this many tags at once is not a reader narrowing a list.
  MAX_TAGS = 6

  before_action :set_post!, only: :show
  before_action :redirect_to_current_address, only: :show

  def index
    readable = Post.active.translated_in(I18n.locale)
    # Each chip carries how many entries it would leave, counted over what this language can
    # read — the same rule the list itself follows.
    @tags = Tag.joins(:posts).where(posts: { id: readable.select(:id) })
               .group('tags.id').order(:title).select('tags.*, COUNT(*) AS readable_count')
    # Looked up in Tag, not in @tags: a tag whose posts are all hidden has no chip but a
    # bookmarked link to it should say "no entries", not silently list everything.
    @active_tags = Tag.where(id: requested_tag_ids).order(:title).to_a
    @order = Post::ORDER_TYPES.include?(params[:order]) ? params[:order] : 'new'
    @entries_count = readable.count

    posts = filtered_posts
    @pagy, @posts = pagy(posts, limit: PER_PAGE, count: filtered_posts_count, raise_range_error: true)
    # A date order reads as a timeline, so it gets year headings; "best" is a ranking, and a
    # year between two places in it would mean nothing.
    @year_counts = year_counts if GROUPED_ORDERS.include?(@order)
  end

  def show
    process_event
    @related = Post.similar_posts(@post).translated_in(I18n.locale).includes(:tags, :user, :translations).to_a
    # Reading order, not publication order: an entry numbered #003 comes after #002 whenever
    # it was written.
    @previous_entry = Post.before(@post).translated_in(I18n.locale).includes(:translations).first
    @next_entry = Post.after(@post).translated_in(I18n.locale).includes(:translations).first
    # The project this entry is about, read off its tags against each case's stack.
    cases = Case.ordered.to_a
    @topic_cases = Cases::Topics.new(cases).cases_for(@post)

    # After the view is recorded, as on /work/:slug: a reader whose browser revalidates still
    # counts. The rich text touches the post, so @post covers the body.
    cache_publicly(@post, @post.user, @post.tags, @related, @related.flat_map(&:tags), @previous_entry, @next_entry,
                   cases)
  end

  # Search moved here from home#search when the front page stopped being the article stream.
  # It kept the /search path — the URL is indexed — but it was the last public page still on
  # the old Bootstrap layout, and nothing in the redesigned nav pointed at it, so the site
  # had a search screen no reader could find.
  def search
    @query = params[:query].to_s.delete("\0").strip
    @field = SEARCH_FIELDS.include?(params[:search_in]) ? params[:search_in] : SEARCH_FIELDS.first

    respond_to do |format|
      format.html do
        results = Posts::Search.call(query: @query, search_in: @field) || Post.none
        @pagy, @results = pagy(results.includes(:tags, :user, :translations), limit: PER_PAGE, raise_range_error: true)
        # The journal's live search asks for the results alone and swaps them in.
        render partial: 'search_results' if params[:partial].present? && @query.present?
      end

      # The command palette. Same action, same query, wider net — it also has to find the
      # cases and the pages, which are not posts.
      format.json { render json: Search::Palette.call(@query, routes: self) }
    end
  end

  private

  def filtered_posts
    posts = ORDERS.fetch(@order) { ORDERS['new'] }.call.translated_in(I18n.locale)
    posts = posts.where(id: carrying_every_active_tag) if @active_tags.any?
    posts.includes(:tags, :user, :translations)
  end

  # AND, not OR: picking a second tag narrows the list. Chips that widen it would make the
  # counts on them meaningless the moment a second one is on.
  def carrying_every_active_tag
    ids = @active_tags.map(&:id)
    Post.joins(:tags).where(tags: { id: ids }).group('posts.id')
        .having('COUNT(DISTINCT tags.id) = ?', ids.size).select('posts.id')
  end

  # ?tag_id=3 (every link before multi-select, and still what one chip produces) or
  # ?tag_id[]=3&tag_id[]=5. Anything else — a nested hash, a word — is not a tag.
  def requested_tag_ids
    raw = params[:tag_id]
    (raw.is_a?(Array) ? raw : [raw]).grep(String).grep(/\A\d{1,18}\z/).uniq.first(MAX_TAGS)
  end

  def year_counts
    filtered_posts.except(:select, :order, :includes).count_by_year
  end

  # Post.best selects a computed column, which COUNT cannot take, so Pagy is handed the count.
  def filtered_posts_count
    filtered_posts.except(:select, :order, :includes).count(:id)
  end

  # FriendlyId's history module already resolves a slug the post used to have, so there is
  # nothing to look up by hand here. home#show used to try, against a friendly_id_slugs.locale
  # column that does not exist — which turned every unknown slug into a 500.
  #
  # Two things this used to get wrong. It looked the post up unscoped, so a post switched to
  # `inactive` vanished from the index but stayed fully readable at its own URL — hiding a
  # draft did not hide it. And an unknown slug redirected to the index, which is a soft 404:
  # the reader gets a page that is not what they asked for, and a crawler is told the link is
  # fine. Both are now the same honest answer, a real 404 on the designed page.
  #
  # Staff keep the unscoped lookup, because previewing a hidden post before publishing it is
  # the reason the two states exist.
  def set_post!
    slug = params.expect(:id)
    raise ActiveRecord::RecordNotFound if slug.include?("\0")

    @post = visible_posts.friendly.find(slug)
    raise ActiveRecord::RecordNotFound unless current_user&.staff_member? || @post.translated_in?(I18n.locale)
  rescue ActiveRecord::RecordNotFound
    raise ActionController::RoutingError, 'post not found'
  end

  def redirect_to_current_address
    return if params[:id] == @post.slug

    redirect_to post_path(@post), status: :moved_permanently
  end

  def visible_posts
    current_user&.staff_member? ? Post.all : Post.active
  end

  def process_event
    ViewTracking.record(self, @post)
  end
end
