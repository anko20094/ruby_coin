# frozen_string_literal: true

module PostsHelper
  def current_data(post, item, locale)
    if action_name == 'create'
      params['post'].present? ? params.dig('post', "#{item}_localizations", locale) : ''
    elsif item == 'description'
      # Bodies are Action Text now, one rich text per locale — not a PostTranslation column.
      post.rich_body(locale)&.body&.to_s
    else
      post.post_translations.find_by(locale:)&.public_send(item)
    end
  end
end
