# frozen_string_literal: true

class Management::PostPolicy < ApplicationPolicy
  def index?
    admin? || moderator?
  end

  def show?
    admin? || moderator?
  end

  # Autosave writes, so it needs what update needs. Preview only reads.
  def autosave?
    update?
  end

  # Translation spends the owner's OpenAI credit, so it is a write in the only sense that
  # matters here — it costs money per call.
  def translate?
    update?
  end

  def preview?
    show?
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
