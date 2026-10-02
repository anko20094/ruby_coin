# frozen_string_literal: true

# The command palette: the button in the nav and the <dialog> it opens. The button matters as
# much as the shortcut — a shortcut nobody is told about does not exist.
class PaletteComponent < ViewComponent::Base
  def search_url = helpers.search_path(format: :json)

  def all_url = helpers.search_path
end
