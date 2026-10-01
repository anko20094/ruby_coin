# frozen_string_literal: true

require 'rails_helper'

# Blocks are inserted while editing an article, so whoever may edit one may make one.
RSpec.describe Management::JournalBlockPolicy do
  subject(:policy) { described_class.new(user, JournalBlock) }

  context 'when the user is an admin' do
    let(:user) { build(:user, :admin) }

    it { expect(policy).to permit_action(:create) }
  end

  context 'when the user is a moderator' do
    let(:user) { build(:user, :moderator) }

    it { expect(policy).to forbid_action(:create) }
  end

  context 'when the user is a reader' do
    let(:user) { build(:user, role: :user) }

    it { expect(policy).to forbid_action(:create) }
  end

  context 'when nobody is signed in' do
    let(:user) { nil }

    it { expect(policy).to forbid_action(:create) }
  end
end
