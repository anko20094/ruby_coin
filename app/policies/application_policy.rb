# frozen_string_literal: true

# Deny by default: a policy opens exactly the actions it names, so a new controller that forgets
# its own policy cannot fall through to a permissive read.
class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?
    false
  end

  def show?
    false
  end

  def create?
    admin?
  end

  def new?
    admin?
  end

  def update?
    admin?
  end

  def edit?
    admin?
  end

  def destroy?
    admin?
  end

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      raise NotImplementedError, "You must define #resolve in #{self.class}"
    end

    private

    attr_reader :user, :scope
  end

  private

  def admin?
    user.present? && user.admin?
  end

  def moderator?
    user.present? && user.moderator?
  end
end
