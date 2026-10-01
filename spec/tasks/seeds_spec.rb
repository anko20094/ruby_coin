# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'db/seeds.rb' do # rubocop:disable RSpec/DescribeClass
  # Wrapped, so the constants the file defines are gone when it has run.
  def seed = capture { load Rails.root.join('db', 'seeds.rb'), true }

  context 'when it runs on a live environment' do
    before do
      allow(Rails.env).to receive(:local?).and_return(false)
      with_env(ALLOW_SEED: '1', SEED_ADMIN_EMAIL: 'owner@example.com', SEED_ADMIN_PASSWORD: 'a-long-secret')
    end

    it 'creates the admin with the password it was given' do
      seed

      admin = User.find_by!(email: 'owner@example.com')
      expect(admin).to be_admin
      expect(admin.valid_password?('a-long-secret')).to be(true)
    end

    it 'creates nothing else, because the deploy owns the portfolio and the journal is real' do
      seed

      expect([Post.count, Case.count, CVProfile.count, Tag.count]).to eq([0, 0, 0, 0])
    end

    it 'leaves an existing admin as it is' do
      existing = create(:user, :admin, email: 'owner@example.com', password: 'the-one-in-use')

      seed

      expect(existing.reload.valid_password?('the-one-in-use')).to be(true)
    end

    it 'refuses to run without a password, and creates no account' do
      with_env(SEED_ADMIN_PASSWORD: nil)

      expect(seed.exit_status).to eq(1)
      expect(User.count).to eq(0)
    end

    it 'refuses to run without an email, and does not fall back to the site address' do
      with_env(SEED_ADMIN_EMAIL: nil)

      expect(seed.exit_status).to eq(1)
      expect(User.where(email: 'admin@rubyco.in')).to be_empty
    end

    it 'does nothing at all unless ALLOW_SEED is set' do
      with_env(ALLOW_SEED: nil)

      expect(seed.exit_status).to be_nil
      expect(User.count).to eq(0)
    end
  end

  context 'when it runs on a development machine' do
    before do
      skip 'ImageMagick is not installed' unless MiniMagick::Utilities.which('magick') || MiniMagick::Utilities.which('convert')

      with_env(ALLOW_SEED: nil, SEED_ADMIN_EMAIL: nil, SEED_ADMIN_PASSWORD: nil)
    end

    it 'gives the admin a random password, printed once, never a published default' do
      run = seed

      admin = User.find_by!(email: 'admin@rubyco.in')
      password = run.stdout[/password: (\S+)/, 1]
      expect(admin.valid_password?(password)).to be(true)
      expect(admin.valid_password?('password123')).to be(false)
    end

    it 'loads the portfolio and the journal, and is idempotent' do
      seed
      counts = [Case.count, CVProfile.count, Post.count, User.count]

      seed

      expect(counts).to eq([7, 1, JournalController::PER_PAGE + 2, 1])
      expect([Case.count, CVProfile.count, Post.count, User.count]).to eq(counts)
    end

    it 'seeds more entries than the journal shows at once, each readable in both languages' do
      seed

      I18nExtended::AVAILABLE_LOCALES.each do |locale|
        expect(Post.active.translated_in(locale).count).to be > JournalController::PER_PAGE
      end
    end
  end
end
