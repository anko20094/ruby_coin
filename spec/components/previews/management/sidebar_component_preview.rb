# frozen_string_literal: true

module Management
  # The /management sidebar, with this database's real counts.
  class SidebarComponentPreview < ViewComponent::Preview
    layout 'component_preview_admin'

    # @label On the post list
    def posts
      render(Management::SidebarComponent.new(user: user, current: :posts))
    end

    # @label On statistics
    def statistics
      render(Management::SidebarComponent.new(user: user, current: :statistics))
    end

    private

    def user = ::User.find_by(role: :admin) || ::User.new(nickname: 'admin', role: :admin)
  end
end
