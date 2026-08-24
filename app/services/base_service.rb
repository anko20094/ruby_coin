# frozen_string_literal: true

class BaseService
  # Keywords pass through too — Search::Palette takes the route helpers that way.
  def self.call(*, **)
    service = new(*, **)

    service.__send__(:call) if service.respond_to?(:call)
  end

  private

  def call
    raise NotImplementedError
  end
end
