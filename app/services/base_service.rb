# frozen_string_literal: true

class BaseService
  # Arguments pass through as given — Search::Palette takes the route helpers as keywords.
  def self.call(...) = new(...).call

  def call
    raise NotImplementedError, "#{self.class} must define #call"
  end
end
