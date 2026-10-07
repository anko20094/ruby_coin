# frozen_string_literal: true

class ErrorsComponentPreview < ViewComponent::Preview
  # @label Site (sign-in, password screens)
  def site
    render(ErrorsComponent.new(object: self.class.invalid_user, tone: :site))
  end

  def self.invalid_user
    User.new.tap do |user|
      user.errors.add(:email, :blank)
      user.errors.add(:password, :too_short, count: 6)
    end
  end
end
