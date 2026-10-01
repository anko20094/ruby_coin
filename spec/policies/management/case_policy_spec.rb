# frozen_string_literal: true

require 'rails_helper'

# Cases carry figures read from production and trackers: staff may look, only an admin edits.
RSpec.describe Management::CasePolicy do
  subject(:policy) { described_class.new(user, Case) }

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
end
