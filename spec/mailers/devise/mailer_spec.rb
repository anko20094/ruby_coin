# frozen_string_literal: true

require 'rails_helper'

# Devise's mail is written in the language the person asked in, and sent by a job that has to
# remember it.
describe Devise::Mailer, :jobs, type: :mailer do
  let!(:user) { create(:user, :admin, email: 'admin@example.com', password: 'password123') }
  let(:mail) { ActionMailer::Base.deliveries.last }

  def sentence(key, locale, **)
    CGI.escapeHTML(I18n.t("devise.mailer.#{key}", locale: locale, **)).gsub("'", '&#39;')
  end

  shared_examples 'mail written in' do |locale, other|
    around { |example| I18n.with_locale(locale, &example) }

    it 'asks for a new password in that language, subject and body' do
      token = user.send_reset_password_instructions
      perform_enqueued_jobs

      expect(mail.subject).to eq(I18n.t('devise.mailer.reset_password_instructions.subject', locale: locale))
      %w[greeting instruction action instruction_2 instruction_3].each do |key|
        expect(mail.body.encoded).to include(sentence("reset_password_instructions.#{key}", locale,
                                                      recipient: user.email))
      end
      expect(mail.body.encoded).to include("/#{locale}/users/password/edit?reset_password_token=#{token}")
    end

    it 'says nothing of it in the other language' do
      user.send_reset_password_instructions
      perform_enqueued_jobs

      %w[instruction instruction_2 instruction_3].each do |key|
        expect(mail.body.encoded).not_to include(sentence("reset_password_instructions.#{key}", other))
      end
    end

    it 'tells the person their password was changed' do
      allow(User).to receive(:send_password_change_notification).and_return(true)
      user.update!(password: 'another-password')
      perform_enqueued_jobs

      expect(mail.subject).to eq(I18n.t('devise.mailer.password_change.subject', locale: locale))
      expect(mail.body.encoded).to include(sentence('password_change.message', locale))
      expect(mail.body.encoded).to include(sentence('password_change.greeting', locale, recipient: user.email))
      expect(mail.body.encoded).not_to include(sentence('password_change.message', other))
    end

    it 'tells the old address that the email was changed' do
      allow(User).to receive(:send_email_changed_notification).and_return(true)
      user.update!(email: 'moved@example.com')
      perform_enqueued_jobs

      expect(mail.to).to eq(['admin@example.com'])
      expect(mail.subject).to eq(I18n.t('devise.mailer.email_changed.subject', locale: locale))
      expect(mail.body.encoded).to include(sentence('email_changed.message', locale, email: 'moved@example.com'))
      expect(mail.body.encoded).not_to include(sentence('email_changed.message', other, email: 'moved@example.com'))
    end
  end

  context 'when the person reads Ukrainian' do
    it_behaves_like 'mail written in', :uk, :en
  end

  context 'when the person reads English' do
    it_behaves_like 'mail written in', :en, :uk
  end

  it 'keeps the language of the request through the queue, whatever the thread that sends is set to' do
    I18n.with_locale(:en) { user.send_reset_password_instructions }

    I18n.with_locale(:uk) { perform_enqueued_jobs }

    expect(mail.subject).to eq(I18n.t('devise.mailer.reset_password_instructions.subject', locale: :en))
  end

  it 'does not send until the job runs' do
    expect { user.send_reset_password_instructions }.not_to(change { ActionMailer::Base.deliveries.size })
    expect { perform_enqueued_jobs }.to change { ActionMailer::Base.deliveries.size }.by(1)
  end
end
