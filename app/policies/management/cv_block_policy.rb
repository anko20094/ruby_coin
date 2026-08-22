# frozen_string_literal: true

class Management::CVBlockPolicy < ApplicationPolicy
  def index?
    admin? || moderator?
  end

  def show?
    admin? || moderator?
  end
end
