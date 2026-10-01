# frozen_string_literal: true

require 'rails_helper'

describe ApplicationMailer, type: :mailer do
  let(:mailer) do
    Class.new(described_class) do
      def self.name = 'GreetingMailer'

      def hello = mail(to: 'reader@example.com', body: 'Hello')
    end
  end

  it 'sends from the address Devise sends from, not from the generator placeholder' do
    expect(mailer.hello.from).to eq([Devise.mailer_sender])
    expect(mailer.hello.from).not_to include('from@example.com')
  end

  it 'follows the configured sender when it is changed' do
    allow(Devise).to receive(:mailer_sender).and_return('site@example.org')

    expect(mailer.hello.from).to eq(['site@example.org'])
  end

  it 'is the address MAILER_FROM names' do
    expect(Devise.mailer_sender).to eq(ENV['MAILER_FROM'].presence || 'no-reply@rubyco.in')
  end
end
