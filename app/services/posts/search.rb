# frozen_string_literal: true

# The journal's search. One pg_search scope per field the reader can pick.
class Posts::Search < BaseService
  attr_accessor :params

  SEARCH = {
    'all' => :search_everywhere,
    'title' => :search_by_title,
    'description' => :search_by_description
  }.freeze

  def initialize(params)
    @params = params
  end

  def call
    return if params[:query].blank?

    Post.active.public_send(search_scope, params[:query])
  end

  # The old version compared against `SEARCH.keys.to_s`, so it was matching a field name
  # against the string "[:all, :title, :description]" — it happened to work for every real
  # value and would have accepted nonsense like ":all" too.
  def search_scope
    SEARCH.fetch(params[:search_in].to_s, SEARCH.fetch('all'))
  end
end
