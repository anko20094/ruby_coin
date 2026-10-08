# frozen_string_literal: true

class Management::CasePolicy < ApplicationPolicy
  def index?
    admin? || moderator?
  end

  def show?
    admin? || moderator?
  end
end
