# frozen_string_literal: true

class PaletteComponent < ViewComponent::Base
  def search_url = helpers.search_path(format: :json)

  def all_url = helpers.search_path
end
