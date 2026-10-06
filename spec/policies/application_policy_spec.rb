# frozen_string_literal: true

require 'rails_helper'

# Every policy inherits from this one, so whatever it allows is allowed wherever a subclass
# forgets to say otherwise.
RSpec.describe ApplicationPolicy do
  subject(:policy) { described_class.new(user, Post) }

  let(:actions) { %i[index show new create edit update destroy] }

  context 'when nobody is signed in' do
    let(:user) { nil }

    it { expect(policy).to forbid_actions(actions) }
  end

  context 'when the user is a reader' do
    let(:user) { build(:user, role: :user) }

    it { expect(policy).to forbid_actions(actions) }
  end

  context 'when the user is a moderator' do
    let(:user) { build(:user, :moderator) }

    it { expect(policy).to forbid_actions(actions) }
  end

  context 'when the user is an admin' do
    let(:user) { build(:user, :admin) }

    it { expect(policy).to forbid_actions(%i[index show]) }
    it { expect(policy).to permit_actions(%i[new create edit update destroy]) }
  end
end
