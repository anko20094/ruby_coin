# frozen_string_literal: true

require 'rails_helper'

# The Devise screens were the last public pages on the old Bootstrap layout — which meant a
# second stylesheet, a second bundle, and a second footer carrying a different Telegram handle,
# a different copyright holder and a dead YouTube link.
describe 'the way in', :jobs, type: :request do
  include_context 'when the cv is imported'

  describe 'GET /users/sign_in' do
    before { get new_user_session_path(locale: 'en') }

    it 'is on the site, not on a second one' do
      expect(response).to be_successful
      expect(response.body).to include('rc-nav')
      expect(response.body).to include('au-page')
    end

    it 'carries the identity the rest of the site carries' do
      expect(response.body).to include(I18n.with_locale(:en) { CVProfile.current.name })
      expect(response.body).not_to include('t.me/ruby4you')
      expect(response.body).not_to include('javascript:void(0)')
    end
  end

  # Propshaft digests every asset name, so a bundle is /assets/application-<digest>.css and
  # never the bare filename.
  describe 'the bundles a page loads' do
    let(:admin_bundles) { %r{/assets/(application|admin)[-\w]*\.(css|js)} }

    [
      '/en/users/sign_in', '/uk/users/sign_in', '/en/users/password/new', '/en', '/en/journal',
      '/en/work', '/en/team', '/en/cv', '/en/contact', '/en/studio', '/en/faq', '/en/search',
      '/404'
    ].each do |path|
      it "loads the theme and nothing built for the admin on #{path}" do
        get path

        expect(response.body).to match(%r{/assets/theme[-\w]*\.css})
        expect(response.body).not_to match(admin_bundles)
      end
    end

    it 'tells the admin bundles apart from the theme on the page that does load them' do
      sign_in create(:user, role: :admin)

      get '/en/management/tags'

      expect(response.body).to match(%r{/assets/application[-\w]*\.css})
      expect(response.body).to match(%r{/assets/admin[-\w]*\.js})
    end
  end

  # There is no member area and no email confirmation, so an open sign-up meant anyone could
  # create an account and gain nothing by it.
  describe 'registration' do
    it 'is closed' do
      get new_user_registration_path(locale: 'en')

      expect(response).to redirect_to(new_user_session_path)
      expect(flash[:alert]).to be_present
    end

    it 'cannot be posted to either' do
      attempt = lambda do
        post user_registration_path(locale: 'en'),
             params: { user: { email: 'stranger@example.com', password: 'password123' } }
      end

      expect(&attempt).not_to change(User, :count)
    end

    it 'is not offered anywhere' do
      get new_user_session_path(locale: 'en')

      expect(response.body).not_to include(new_user_registration_path(locale: 'en'))
    end
  end

  it 'still lets an account that exists sign in' do
    user = create(:user, role: :admin, password: 'password123')

    post user_session_path(locale: 'en'), params: { user: { email: user.email, password: 'password123' } }

    expect(response).to be_redirect
    follow_redirect!
    expect(response).to be_successful
  end

  it 'does not say whether it was the address or the password that was wrong' do
    user = create(:user, role: :admin, password: 'password123')

    post user_session_path(locale: 'en'), params: { user: { email: user.email, password: 'wrong-password' } }
    known = [response.status, response.body[/class="rc-flash__text">([^<]*)/, 1]]
    post user_session_path(locale: 'en'),
         params: { user: { email: 'stranger@example.com', password: 'wrong-password' } }

    expect(known.last).to be_present
    expect([response.status, response.body[/class="rc-flash__text">([^<]*)/, 1]]).to eq(known)
  end

  describe 'a request that is not for a page' do
    let!(:user) { create(:user, :admin, password: 'password123') }
    let(:credentials) { { user: { email: user.email, password: 'password123' } } }

    ['/en/users/sign_in.json', '/en/users/sign_in.xml'].each do |path|
      it "refuses to sign anybody in on #{path}" do
        post path, params: credentials

        expect(response).to have_http_status(:not_acceptable)
        get management_root_path(locale: 'en')
        expect(response.location).to include('/users/sign_in')
      end

      it "answers a wrong password on #{path} as it answers a right one" do
        post path, params: credentials
        right = [response.status, response.media_type]
        post path, params: { user: { email: user.email, password: 'wrong-password' } }

        expect([response.status, response.media_type]).to eq(right)
      end
    end

    it 'refuses a json body that asks for json' do
      post user_session_path(locale: 'en'), params: credentials, as: :json

      expect(response).to have_http_status(:not_acceptable)
    end

    it 'refuses to send a reset mail on .json' do
      asking = lambda do
        post '/en/users/password.json', params: { user: { email: user.email } }
        perform_enqueued_jobs
      end

      expect(&asking).not_to(change { ActionMailer::Base.deliveries.size })
      expect(response).to have_http_status(:not_acceptable)
    end

    it 'refuses to choose a password on .json' do
      put '/en/users/password.json',
          params: { user: { reset_password_token: 'x', password: 'a-new-one', password_confirmation: 'a-new-one' } }

      expect(response).to have_http_status(:not_acceptable)
    end

    it 'refuses to change the account on .json' do
      sign_in user

      patch '/en/users.json', params: { user: { nickname: 'renamed', current_password: 'password123' } }

      expect(response).to have_http_status(:not_acceptable)
      expect(user.reload.nickname).not_to eq('renamed')
    end

    it 'still answers a script that asks for anything' do
      post user_session_path(locale: 'en'), params: credentials, headers: { 'Accept' => '*/*' }

      expect(response).to be_redirect
    end

    it 'still answers a browser' do
      post user_session_path(locale: 'en'), params: credentials,
                                            headers: { 'Accept' => 'text/html,application/xhtml+xml,*/*;q=0.8' }

      expect(response).to be_redirect
    end

    it 'still answers a form sent with an explicit html format' do
      post '/en/users/sign_in.html', params: credentials

      expect(response).to be_redirect
    end

    it 'still signs out' do
      sign_in user

      delete destroy_user_session_path(locale: 'en')

      expect(response).to be_redirect
    end
  end

  describe 'a forgotten password' do
    let!(:user) { create(:user, role: :admin, email: 'admin@example.com', password: 'password123') }

    def request_a_reset(email, locale: 'en')
      post user_password_path(locale: locale), params: { user: { email: email } }
    end

    def ask_for_a_reset(email, locale: 'en')
      request_a_reset(email, locale: locale)
      perform_enqueued_jobs
    end

    def choose_a_password(token, password: 'a-new-password')
      put user_password_path(locale: 'en'),
          params: { user: { reset_password_token: token, password: password, password_confirmation: password } }
    end

    def reset_token
      ActionMailer::Base.deliveries.last.body.encoded[/reset_password_token=([^"&\s]+)/, 1]
    end

    it 'is asked for on the site, not on a second one' do
      get new_user_password_path(locale: 'en')

      expect(response).to be_successful
      expect(response.body).to include('rc-nav')
      expect(response.body).to include('au-page')
    end

    it 'sends one mail to an account that exists, and sends the person back to sign in' do
      expect { ask_for_a_reset(user.email) }.to change { ActionMailer::Base.deliveries.size }.by(1)

      expect(response).to redirect_to(new_user_session_path(locale: 'en'))
    end

    it 'sends it from an address on the site, not from the generator placeholder' do
      ask_for_a_reset(user.email)

      expect(ActionMailer::Base.deliveries.last.from).to eq(['no-reply@rubyco.in'])
    end

    context 'when the mail is sent' do
      it 'leaves the relay to a job, so the answer does not wait on it' do
        expect { request_a_reset(user.email) }.not_to(change { ActionMailer::Base.deliveries.size })
        expect { perform_enqueued_jobs }.to change { ActionMailer::Base.deliveries.size }.by(1)
      end

      it 'queues one mail for an account that exists' do
        expect { request_a_reset(user.email) }
          .to have_enqueued_mail(Devise::Mailer, :reset_password_instructions).exactly(:once)
      end

      it 'queues nothing for an address that is not an account' do
        expect { request_a_reset('stranger@example.com') }.not_to have_enqueued_job
      end

      it 'keeps the reset token out of the job log' do
        log = StringIO.new
        original = ActiveJob::Base.logger
        ActiveJob::Base.logger = ActiveSupport::Logger.new(log)

        begin
          ask_for_a_reset(user.email)
        ensure
          ActiveJob::Base.logger = original
        end

        expect(log.string).to include('MailDeliveryJob')
        expect(log.string).not_to include(reset_token)
      end
    end

    shared_examples 'a mail written in' do |locale, other|
      let(:mail) { ActionMailer::Base.deliveries.last }
      let(:parts) { %w[greeting instruction action instruction_2 instruction_3] }

      before { ask_for_a_reset(user.email, locale: locale) }

      it 'is in that language, subject and body' do
        expect(mail.subject).to eq(I18n.t('devise.mailer.reset_password_instructions.subject', locale: locale))
        parts.each do |key|
          text = I18n.t("devise.mailer.reset_password_instructions.#{key}", locale: locale, recipient: user.email)
          expect(mail.body.encoded).to include(CGI.escapeHTML(text).gsub("'", '&#39;'))
        end
      end

      it 'says none of it in the other language' do
        text = I18n.t('devise.mailer.reset_password_instructions.instruction', locale: other)

        expect(mail.body.encoded).not_to include(text)
      end

      it 'links to the form in that language' do
        expect(mail.body.encoded).to include("/#{locale}/users/password/edit?reset_password_token=")
      end
    end

    context 'when the person asked in Ukrainian' do
      it_behaves_like 'a mail written in', 'uk', 'en'
    end

    context 'when the person asked in English' do
      it_behaves_like 'a mail written in', 'en', 'uk'
    end

    it 'sends a link that opens the form to choose a new password, on the site' do
      ask_for_a_reset(user.email)
      get edit_user_password_path(locale: 'en', reset_password_token: reset_token)

      expect(response).to be_successful
      expect(response.body).to include('rc-nav')
      expect(response.body).to include('name="user[password]"')
    end

    it 'sets the new password with the link, and signs the person in' do
      ask_for_a_reset(user.email)
      choose_a_password(reset_token)

      expect(user.reload.valid_password?('a-new-password')).to be(true)
      expect(response).to be_redirect
      follow_redirect!
      expect(response).to be_successful
    end

    it 'rejects a link it did not send' do
      choose_a_password('not-a-token')

      expect(response).to have_http_status(:unprocessable_content)
      expect(user.reload.valid_password?('password123')).to be(true)
    end

    # The only way back into the admin is this form, so it must not be the way to find out
    # which address the admin is.
    context 'when the address is not an account' do
      it 'answers exactly as it does for one that is' do
        ask_for_a_reset(user.email)
        known = [response.status, response.location, flash[:notice]]

        ask_for_a_reset('stranger@example.com')

        expect([response.status, response.location, flash[:notice]]).to eq(known)
      end

      it 'sends nothing' do
        expect { ask_for_a_reset('stranger@example.com') }.not_to(change { ActionMailer::Base.deliveries.size })
      end

      %w[en uk].each do |locale|
        it "says the same neutral thing in #{locale}" do
          ask_for_a_reset('stranger@example.com', locale: locale)
          follow_redirect!

          neutral = I18n.t('devise.passwords.send_paranoid_instructions', locale: locale, raise: true)
          expect(response.body).to include(CGI.escapeHTML(neutral))
          expect(response.body).not_to include('rc-flash__item--alert')
        end
      end
    end
  end
end
