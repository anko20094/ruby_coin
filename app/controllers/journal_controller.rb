# frozen_string_literal: true

# The article stream on the new theme. A re-skin of Post — no new data, except the stored
# entry number. home#index keeps the old stream until W7 takes the front page.
class JournalController < ApplicationController
  layout 'theme'

  # The index is a row list at 1100px, not the card grid home uses, so it carries far more
  # than Post::PAGY_LIMIT rows before paging.
  PER_PAGE = 20

  # Which half of a post to look in. 'all' first, because it is the default.
  SEARCH_FIELDS = %w[all title description].freeze

  # One entry per Post::ORDER_TYPES, so adding an ordering means adding it in both places or
  # the fetch falls back rather than raising.
  ORDERS = {
    'new' => -> { Post.active },
    'oldest' => -> { Post.oldest },
    'best' => -> { Post.best }
  }.freeze

  before_action :set_post!, only: :show

  def index
    @tags = Tag.joins(:posts).where(posts: { status: :active }).distinct.order(:title)
    # Looked up in Tag, not in @tags: a tag whose posts are all hidden has no chip but a
    # bookmarked link to it should say "no entries", not silently list everything.
    @active_tag = Tag.find_by(id: params[:tag_id])
    @order = Post::ORDER_TYPES.include?(params[:order]) ? params[:order] : 'new'
    @entries_count = Post.active.count

    posts = filtered_posts
    @pagy, @posts = pagy(posts, limit: PER_PAGE, count: filtered_posts_count)
  end

  def show
    process_event
    @related = Post.similar_posts(@post).includes(:tags, :user, :translations)
    # Reading order, not publication order: an entry numbered #003 comes after #002 whenever
    # it was written.
    @previous_entry = Post.before(@post).includes(:translations).first
    @next_entry = Post.after(@post).includes(:translations).first
  end

  # Search moved here from home#search when the front page stopped being the article stream.
  # It kept the /search path — the URL is indexed — but it was the last public page still on
  # the old Bootstrap layout, and nothing in the redesigned nav pointed at it, so the site
  # had a search screen no reader could find.
  def search
    @query = params[:query].to_s.strip
    @field = SEARCH_FIELDS.include?(params[:search_in]) ? params[:search_in] : SEARCH_FIELDS.first

    respond_to do |format|
      format.html do
        results = Posts::Search.call(query: @query, search_in: @field) || Post.none
        @pagy, @results = pagy(results.includes(:tags, :user, :translations), limit: PER_PAGE)
      end

      # The command palette. Same action, same query, wider net — it also has to find the
      # cases and the pages, which are not posts.
      format.json { render json: Search::Palette.call(@query, routes: self) }
    end
  end

  private

  def filtered_posts
    posts = ORDERS.fetch(@order, ORDERS['new']).call
    posts = posts.joins(:tags).where(tags: { id: @active_tag.id }) if @active_tag
    # :translations, not :post_translations — Mobility's Table backend reads the association
    # it defines, so preloading only the app's own name left one Post::Translation query per
    # row on this page. Both are named where both are read (the admin list).
    posts.includes(:tags, :user, :translations)
  end

  # Post.best groups by post id, so the relation's own count returns a hash per group rather
  # than a number. Pagy needs the row count, which is the number of distinct posts.
  def filtered_posts_count
    filtered_posts.except(:group, :select, :order, :includes).distinct.count(:id)
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
    @post = visible_posts.friendly.find(params.expect(:id))
  rescue ActiveRecord::RecordNotFound
    raise ActionController::RoutingError, 'post not found'
  end

  def visible_posts
    current_user&.staff_member? ? Post.all : Post.active
  end

  def process_event
    ViewTracking.record(self, @post)
  end
end
