# frozen_string_literal: true

class HomeController < ApplicationController
  def index
    @tags = Tag.joins(:posts).where(posts: { status: :active }).distinct.limit(5)
    @active_tags = params[:tag_ids]

    posts = Posts::Filter.call(active_collection, params)
    @main_post = Post.active.find_by(main_post: true)
    @pagy, @posts = pagy(posts, limit: 6, fragment: '#posts-list')
  end

  def search
    @posts = Posts::Filter.call(active_collection, { order: 'RANDOM()' }).limit(Post::LIMIT_COUNT)
    @results = Posts::Search.call(search_params)
    @results = Posts::Filter.call(@results, params) if @results.present?
  end

  private

  def search_params
    params.permit(:query, :search_in)
  end

  def active_collection
    Post.active
  end
end
