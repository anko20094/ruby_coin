# frozen_string_literal: true

module Statistics
  class PostViewsQuery < BaseQuery
    LIMIT = 50

    def call
      counts = Ahoy::Event.where(name: 'Viewed Post')
                          .group(Arel.sql("properties->>'post_id'"))
                          .order(Arel.sql('count_all DESC'))
                          .limit(LIMIT)
                          .count

      posts = Post.where(id: counts.keys.compact).select(:id, :slug).includes(:translations)
                  .index_by { |post| post.id.to_s }

      counts.filter_map do |id, views|
        post = posts[id]
        [post, views] if post
      end
    end
  end
end
