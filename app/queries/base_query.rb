# frozen_string_literal: true

# A query is built with what it needs and answers through #call, like a service.
class BaseQuery
  def self.call(...) = new(...).call

  def call
    raise NotImplementedError, "#{self.class} must define #call"
  end
end
