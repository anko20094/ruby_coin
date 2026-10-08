# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User do
  subject { build(:user) }

  describe 'associations' do
    it { is_expected.to have_many(:posts).dependent(:destroy) }
  end

  describe '#destroy' do
    let!(:user) { create(:user) }
    let!(:entry) { create(:post, user: user) }

    it 'takes the posts with it, and what hangs off them' do
      user.destroy

      expect(Post.where(id: entry.id)).to be_empty
      expect(PostTranslation.where(post_id: entry.id)).to be_empty
      expect(ActionText::RichText.where(record_type: 'Post', record_id: entry.id)).to be_empty
    end

    it 'leaves other people posts alone' do
      other = create(:post)

      expect { user.destroy }.to change(Post, :count).by(-1)
      expect(Post.exists?(other.id)).to be(true)
    end
  end

  describe 'enums' do
    it { is_expected.to define_enum_for(:role).with_values(admin: 0, moderator: 1, user: 2) }
  end

  describe 'validations' do
    it 'validates that :nickname is case-insensitively and unique' do
      existing_user = build(:user, nickname: 'JohnDoe')
      new_user = build(:user, nickname: existing_user.nickname.upcase)
      expect(new_user).to be_valid
    end

    it 'validates that :email is case-insensitively unique' do
      existing_user = build(:user, email: 'something@gmail.com')
      new_user = build(:user, email: existing_user.email.upcase)
      expect(new_user).to be_valid
    end

    it { is_expected.to validate_presence_of(:nickname).on(:update) }
    it { is_expected.to validate_uniqueness_of(:nickname).case_insensitive.on(:update) }

    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_uniqueness_of(:email).case_insensitive }
  end
end
