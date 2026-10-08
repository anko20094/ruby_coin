# frozen_string_literal: true

class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable, :confirmable
  devise :database_authenticatable, :registerable, :recoverable, :rememberable, :validatable
  mount_uploader :avatar, PhotoUploader

  before_create :set_nickname

  has_many :posts, dependent: :destroy

  validates :nickname, presence: true, uniqueness: { case_sensitive: false }, on: :update
  validates :email, presence: true
  validates :email, uniqueness: true, format: { with: Devise.email_regexp }, if: -> { email.present? }

  enum :role, { admin: 0, moderator: 1, user: 2 }

  scope :confirmed, -> { where.not(confirmed_at: nil) }
  scope :unconfirmed, -> { where(confirmed_at: nil) }

  def confirmed?
    confirmed_at.present?
  end

  def confirm!
    update(confirmed_at: Time.zone.now)
  end

  def staff_member?
    admin? || moderator?
  end

  protected

  # Queued: sent inline, a known address answers slower than an unknown one, which :paranoid
  # exists to hide.
  def send_devise_notification(notification, *)
    devise_mailer.public_send(notification, self, *).deliver_later
  end

  private

  def set_nickname
    self.nickname = email.split('@').first
    num = 2

    until User.find_by(nickname:).nil?
      self.nickname = "#{nickname}_#{num}"
      num += 1
    end
  end
end
