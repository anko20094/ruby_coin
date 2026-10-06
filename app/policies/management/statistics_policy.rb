# frozen_string_literal: true

class Management::StatisticsPolicy < ApplicationPolicy
  def index?
    admin? || moderator?
  end
end
