# frozen_string_literal: true

module Api
  class TagsController < ApplicationController
    # How many suggestions a picker can usefully show at once.
    LIMIT = 20

    before_action :authenticate_user!
    before_action :authorize_staff!

    def index
      render json: TagBlueprint.render(matching_tags)
    end

    private

    # The term is escaped rather than pasted in: `%` and `_` in a search box are characters the
    # reader typed, not wildcards they asked for.
    def matching_tags
      term = params[:term].to_s.strip
      scope = Tag.order(:title).limit(LIMIT)
      return scope if term.blank?

      scope.where('title ILIKE ?', "%#{Tag.sanitize_sql_like(term)}%")
    end

    def authorize_staff!
      authorize %i[management Tag], :index?
    end
  end
end
