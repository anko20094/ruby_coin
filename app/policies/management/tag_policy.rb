# frozen_string_literal: true

class Management::TagPolicy < ApplicationPolicy
  def index?
    admin? || moderator?
  end

  def show?
    admin? || moderator?
  end

  class Scope < Scope
    def resolve
      # Tags are editorial metadata, not public content: there is no anonymous tag list, and
      # no tags.status column to filter one by. This used to ask for that column and raise.
      user.present? && user.staff_member? ? scope.all : scope.none
    end
  end
end
