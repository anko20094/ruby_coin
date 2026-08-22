# frozen_string_literal: true

# Cases carry figures read from production and trackers, so editing them is an admin job.
# index? and show? follow Management::PostPolicy in letting a moderator look.
class Management::CasePolicy < ApplicationPolicy
  def index?
    admin? || moderator?
  end

  def show?
    admin? || moderator?
  end
end
