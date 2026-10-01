# frozen_string_literal: true

require 'rails_helper'

# An upload endpoint is a place to park files, so only the people who may edit a post reach it.
RSpec.describe Management::EditorImagePolicy do
  subject(:policy) { described_class.new(user, :editor_image) }

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
