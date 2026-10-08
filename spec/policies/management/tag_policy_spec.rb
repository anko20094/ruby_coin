# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Management::TagPolicy do
  subject(:policy) { described_class.new(user, Tag) }

  let(:reads) { %i[index show] }
  let(:writes) { %i[new create edit update destroy] }

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

  # Tags are editorial metadata: there is no anonymous tag list.
  describe 'Scope' do
    subject(:resolved) { described_class::Scope.new(user, Tag).resolve }

    let!(:tag) { create(:tag) }

    context 'when the user is an admin' do
      let(:user) { build(:user, :admin) }

      it { is_expected.to contain_exactly(tag) }
    end

    context 'when the user is a moderator' do
      let(:user) { build(:user, :moderator) }

      it { is_expected.to contain_exactly(tag) }
    end

    context 'when the user is a reader' do
      let(:user) { build(:user, role: :user) }

      it { is_expected.to be_empty }
    end

    context 'when nobody is signed in' do
      let(:user) { nil }

      it { is_expected.to be_empty }
    end
  end
end
