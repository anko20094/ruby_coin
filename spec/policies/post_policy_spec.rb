# frozen_string_literal: true

require 'rails_helper'

# `authorize @post` in Management::PostsController#create is handed a Post, and Pundit resolves
# that to this policy rather than to Management::PostPolicy — so #create? is the one that
# guards creating a post.
RSpec.describe PostPolicy do
  subject(:policy) { described_class.new(user, Post.new) }

  let(:writes) { %i[new create edit update destroy] }
  let(:reads) { %i[index show] }

  it 'is the policy a Post instance resolves to' do
    expect(Pundit::PolicyFinder.new(Post.new).policy).to eq(described_class)
  end

  context 'when the user is an admin' do
    let(:user) { build(:user, :admin) }

    it { expect(policy).to permit_actions(reads + writes) }
  end

  context 'when the user is a moderator' do
    let(:user) { build(:user, :moderator) }

    it { expect(policy).to forbid_actions(reads + writes) }
  end

  context 'when the user is a reader' do
    let(:user) { build(:user, role: :user) }

    it { expect(policy).to forbid_actions(reads + writes) }
  end

  context 'when nobody is signed in' do
    let(:user) { nil }

    it { expect(policy).to forbid_actions(reads + writes) }
  end

  describe PostPolicy::Scope do
    it 'resolves to every post' do
      post = create(:post)

      expect(described_class.new(nil, Post).resolve).to include(post)
    end
  end
end
