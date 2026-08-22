# frozen_string_literal: true

# Blocks are inserted while editing an article, so whoever may edit an article may make one.
# ApplicationPolicy#create? is admin-only, which matches Management::PostsController.
class Management::JournalBlockPolicy < ApplicationPolicy
end
