# frozen_string_literal: true

# Uploading an image happens while editing an article, so whoever may edit one may upload.
# ApplicationPolicy#create? is admin-only, which matches Management::PostsController.
class Management::EditorImagePolicy < ApplicationPolicy
end
