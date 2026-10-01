# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StatisticsPolicy do
  subject(:policy) { described_class.new(user, :statistics) }

  it 'is the policy :statistics resolves to' do
    expect(Pundit::PolicyFinder.new(:statistics).policy).to eq(described_class)
  end

  context 'when the user is an admin' do
    let(:user) { build(:user, :admin) }

    it { expect(policy).to permit_action(:index) }
  end

  context 'when the user is a moderator' do
    let(:user) { build(:user, :moderator) }

    it { expect(policy).to permit_action(:index) }
  end

  context 'when the user is a reader' do
    let(:user) { build(:user, role: :user) }

    it { expect(policy).to forbid_action(:index) }
  end

  context 'when nobody is signed in' do
    let(:user) { nil }

    it { expect(policy).to forbid_action(:index) }
  end
end
