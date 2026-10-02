# frozen_string_literal: true

# The legacy rows as they are, `description` included: Post::Translation (Mobility's class over
# the same table) ignores that column, and only the bodies-to-Action-Text task still reads it.
class PostTranslation < ApplicationRecord
  belongs_to :post
end
