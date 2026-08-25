# frozen_string_literal: true

module PostsHelper
  # What to show in the *other* locale's title and lede boxes.
  #
  # Whatever was submitted wins, and `nil` is the only fallback trigger — an empty string is a
  # field the author deliberately cleared, not an absent one. This used to key off
  # `action_name == 'create'`, so a failed #update re-read post_translations from the database.
  # #persist wraps both writes in one transaction and rolls back, so that read returned the
  # pre-edit value: pressing Save with a blank title silently reverted the other language.
  def current_data(post, item, locale)
    submitted = params.dig('post', "#{item}_localizations", locale)
    return submitted unless submitted.nil?

    if item == 'description'
      # Bodies are Action Text now, one rich text per locale — not a PostTranslation column.
      post.rich_body(locale)&.body&.to_s
    else
      post.post_translations.find_by(locale:)&.public_send(item)
    end
  end
end
