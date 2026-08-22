# frozen_string_literal: true

# The article stream on the new theme. A re-skin of Post — no new data, except the stored
# entry number. home#index keeps the old stream until W7 takes the front page.
class JournalController < ApplicationController
  layout 'theme'

  # The index is a row list at 1100px, not the card grid home uses, so it carries far more
  # than Post::PAGY_LIMIT rows before paging.
  PER_PAGE = 20

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
    @related = Post.similar_posts(@post).includes(:tags, :user)
  end

  private

  def filtered_posts
    posts = @order == 'best' ? Post.best : Post.active
    posts = posts.joins(:tags).where(tags: { id: @active_tag.id }) if @active_tag
    posts.includes(:tags, :user)
  end

  # Post.best groups by post id, so the relation's own count returns a hash per group rather
  # than a number. Pagy needs the row count, which is the number of distinct posts.
  def filtered_posts_count
    filtered_posts.except(:group, :select, :order, :includes).distinct.count(:id)
  end

  # FriendlyId's history module already resolves a slug the post used to have, so there is
  # nothing to look up by hand here. home#show used to try, against a friendly_id_slugs.locale
  # column that does not exist — which turned every unknown slug into a 500 instead of this
  # redirect.
  def set_post!
    @post = Post.friendly.find(params.expect(:id))
  rescue ActiveRecord::RecordNotFound
    redirect_to journal_path, alert: t('journal.show.errors.not_found')
  end

  def last_visit_for_post
    request.session["last_visit_#{@post.id}"]
  end

  def process_event
    validator = Ahoy::VisitsValidator.new(last_visit_for_post:)
    Ahoy::EventProcess.call(ahoy, @post, request) if validator.valid?
  end
end
