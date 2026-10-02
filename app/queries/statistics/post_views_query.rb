# frozen_string_literal: true

module Statistics
  # Views per post.
  #
  # This used to `group(:properties)` — the whole JSONB blob — so a post whose title changed
  # after some views were recorded appeared twice, once under each title, with the counts
  # split between them. It groups by the id now, and reads the title from the post rather than
  # from whatever was stored at view time.
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
