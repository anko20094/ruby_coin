# frozen_string_literal: true

require 'rails_helper'

# Management::PostsController authorizes [:management, Post] before every action, so each
# action name below is a method that really runs. Moderators may look but not write: #preview
# only reads, #autosave and #translate write (translate spends the OpenAI credit).
RSpec.describe Management::PostPolicy do
  subject(:policy) { described_class.new(user, Post) }

  let(:reads) { %i[index show preview] }
  let(:writes) { %i[new create edit update destroy autosave translate] }

  it 'is the policy [:management, Post] resolves to' do
    expect(Pundit::PolicyFinder.new([:management, Post]).policy).to eq(described_class)
  end

  context 'when the user is an admin' do
    let(:user) { build(:user, :admin) }

    it { expect(policy).to permit_actions(reads + writes) }
  end

  context 'when the user is a moderator' do
    let(:user) { build(:user, :moderator) }

    it { expect(policy).to permit_actions(reads) }
    it { expect(policy).to forbid_actions(writes) }
  end

  context 'when the user is a reader' do
    let(:user) { build(:user, role: :user) }

    it { expect(policy).to forbid_actions(reads + writes) }
  end

  context 'when nobody is signed in' do
    let(:user) { nil }

    it { expect(policy).to forbid_actions(reads + writes) }
  end
end
