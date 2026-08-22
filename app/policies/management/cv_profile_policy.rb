# frozen_string_literal: true

class Management::CVProfilePolicy < ApplicationPolicy
  def show?
    admin? || moderator?
  end
end
