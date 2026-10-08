# frozen_string_literal: true

module PostsHelper
  # What to show in the *other* locale's title and lede boxes.
  #
  # Whatever was submitted wins, and `nil` is the only fallback trigger — an empty string is a
  # field the author deliberately cleared, not an absent one. This used to key off
  # `action_name == 'create'`, so a failed #update re-read the translations from the database.
  # #persist wraps both writes in one transaction and rolls back, so that read returned the
  # pre-edit value: pressing Save with a blank title silently reverted the other language.
  def current_data(post, item, locale)
    submitted = params.dig('post', "#{item}_localizations", locale)
    return submitted unless submitted.nil?

    post.public_send(:"#{item}_#{locale}")
  end
end
