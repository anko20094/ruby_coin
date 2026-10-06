# frozen_string_literal: true

class BaseQuery
  def self.call(...) = new(...).call

  def call
    raise NotImplementedError, "#{self.class} must define #call"
  end
end
