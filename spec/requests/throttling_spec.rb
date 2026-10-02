# frozen_string_literal: true

require 'rails_helper'

# Sign-in, password reset and the search screen are metered; a script cannot sit on them.
describe 'throttling', type: :request do
  # Counters live in fixed windows, so a run that straddles a minute would split its attempts.
  before { travel_to(Time.zone.local(2026, 10, 1, 12, 0, 30)) }

  around do |example|
    Rack::Attack.enabled = true
    Rack::Attack.cache.store.clear
    example.run
  ensure
    Rack::Attack.enabled = false
    Rack::Attack.cache.store.clear
  end

  def sign_in_attempt(email: 'someone@example.com', ip: '203.0.113.10', path: user_session_path(locale: 'en'), **)
    post path, params: { user: { email: email, password: 'wrong-password' } }, env: { 'REMOTE_ADDR' => ip }, **
  end

  def reset_attempt(path: user_password_path(locale: 'en'), ip: '203.0.113.10')
    post path, params: { user: { email: 'someone@example.com' } }, env: { 'REMOTE_ADDR' => ip }
  end

  it 'lets a person mistype their password a few times' do
    3.times { sign_in_attempt }

    expect(response).not_to have_http_status(:too_many_requests)
  end

  it 'stops a script sitting on the sign-in form' do
    11.times { |n| sign_in_attempt(email: "guess#{n}@example.com") }

    expect(response).to have_http_status(:too_many_requests)
  end

  it 'only stops the address that sat on the form' do
    11.times { |n| sign_in_attempt(email: "guess#{n}@example.com") }
    sign_in_attempt(email: 'guess99@example.com', ip: '203.0.113.11')

    expect(response).not_to have_http_status(:too_many_requests)
  end

  it 'says how long to wait, in a way a person can read' do
    11.times { sign_in_attempt }

    expect(response.headers['retry-after']).to be_present
    expect(response.body).to include('Try again')
  end

  # An attacker rotating IPs against one account is the case the per-IP rule misses.
  it 'answers in the language of the page that was asked for' do
    11.times { sign_in_attempt(path: '/uk/users/sign_in') }

    expect(response.body).to include('Забагато запитів', 'Спробуйте ще раз через 60 секунд')
    expect(response.body).not_to include('Try again')
  end

  it 'answers in the default language where the path names none' do
    11.times { sign_in_attempt(path: '/users/sign_in') }

    expect(response.body).to include(I18n.t('throttled', count: 60, locale: I18n.default_locale))
  end

  it 'counts attempts against one account across addresses' do
    11.times { |n| sign_in_attempt(email: 'victim@example.com', ip: "203.0.113.#{n + 20}") }

    expect(response).to have_http_status(:too_many_requests)
  end

  it 'counts an account by the address Devise reads, not by its spelling' do
    10.times { |n| sign_in_attempt(email: 'Victim@Example.com ', ip: "203.0.113.#{n + 20}") }
    sign_in_attempt(email: 'victim@example.com', ip: '203.0.113.99')

    expect(response).to have_http_status(:too_many_requests)
  end

  it 'keeps its counters out of the app cache, whose file store never reclaims a bucket' do
    expect(Rack::Attack.cache.store).to be_a(ActiveSupport::Cache::MemoryStore)
    expect(Rack::Attack.cache.store).not_to equal(Rails.cache)
  end

  it 'never meters assets' do
    400.times { get '/assets/theme.css', env: { 'REMOTE_ADDR' => '203.0.113.99' } }

    expect(response).not_to have_http_status(:too_many_requests)
  end

  # Devise answers the same route under a format suffix, a trailing slash, either locale or none
  # and a doubled slash, so a throttle that reads the raw path is one rewrite away from useless.
  describe 'every address the sign-in route answers on' do
    def self.paths
      {
        'a format suffix' => '/en/users/sign_in.html',
        'a json suffix' => '/en/users/sign_in.json',
        'an xml suffix' => '/en/users/sign_in.xml',
        'a trailing slash' => '/en/users/sign_in/',
        'a suffix and a trailing slash' => '/en/users/sign_in.json/',
        'no locale' => '/users/sign_in',
        'the other locale' => '/uk/users/sign_in',
        'a doubled slash' => '/en//users/sign_in'
      }
    end

    paths.each do |name, path|
      it "stops a script by address behind #{name}" do
        11.times { |n| sign_in_attempt(email: "guess#{n}@example.com", path: path) }

        expect(response).to have_http_status(:too_many_requests)
      end

      it "counts one account across addresses behind #{name}" do
        11.times { |n| sign_in_attempt(email: 'victim@example.com', ip: "203.0.113.#{n + 20}", path: path) }

        expect(response).to have_http_status(:too_many_requests)
      end
    end

    it 'is one counter for all of them' do
      variants = self.class.paths.values + [user_session_path(locale: 'en')]
      variants.cycle.first(11).each { |path| sign_in_attempt(path: path) }

      expect(response).to have_http_status(:too_many_requests)
    end

    it 'is one counter per account for all of them, across addresses' do
      variants = self.class.paths.values + [user_session_path(locale: 'en')]
      variants.cycle.first(11).each_with_index do |path, n|
        sign_in_attempt(email: 'victim@example.com', ip: "203.0.113.#{n + 20}", path: path)
      end

      expect(response).to have_http_status(:too_many_requests)
    end
  end

  describe 'a sign-in sent as json' do
    ['/en/users/sign_in', '/en/users/sign_in.json'].each do |path|
      it "stops a script by address on #{path}" do
        11.times { |n| sign_in_attempt(email: "guess#{n}@example.com", path: path, as: :json) }

        expect(response).to have_http_status(:too_many_requests)
      end

      it "counts one account across addresses on #{path}" do
        11.times { |n| sign_in_attempt(email: 'victim@example.com', ip: "203.0.113.#{n + 20}", path: path, as: :json) }

        expect(response).to have_http_status(:too_many_requests)
      end
    end

    it 'counts the same account whether the body is json or a form' do
      5.times { |n| sign_in_attempt(email: 'victim@example.com', ip: "203.0.113.#{n + 20}", as: :json) }
      5.times { |n| sign_in_attempt(email: 'victim@example.com', ip: "203.0.113.#{n + 40}") }
      sign_in_attempt(email: 'victim@example.com', ip: '203.0.113.99', as: :json)

      expect(response).to have_http_status(:too_many_requests)
    end
  end

  # Devise reads the query string over the body, so the account a rotating attacker is
  # guessing is the one in the query.
  it 'counts the account Devise reads when the query string and the body disagree' do
    11.times do |n|
      post "#{user_session_path(locale: 'en')}?user[email]=victim@example.com",
           params: { user: { email: "decoy#{n}@example.com", password: 'wrong-password' } },
           env: { 'REMOTE_ADDR' => "203.0.113.#{n + 20}" }
    end

    expect(response).to have_http_status(:too_many_requests)
  end

  describe 'a sign-in that is not shaped like one' do
    shapes = {
      'a string for user' => { user: 'x' },
      'a list for user' => { user: %w[x y] },
      'a list for the email' => { user: { email: %w[a@example.com b@example.com], password: 'x' } },
      'a hash for the email' => { user: { email: { a: 'b' }, password: 'x' } },
      'no user at all' => {}
    }

    shapes.each do |name, params|
      it "answers #{name} like the form would, not with a server error" do
        post user_session_path(locale: 'en'), params: params

        expect(response).to have_http_status(:unprocessable_content)
      end

      it "still counts #{name} against the address" do
        11.times { post user_session_path(locale: 'en'), params: params, env: { 'REMOTE_ADDR' => '203.0.113.10' } }

        expect(response).to have_http_status(:too_many_requests)
      end
    end

    it 'answers a json body that is not json with the client error it always was' do
      post user_session_path(locale: 'en'), params: '{"user":', headers: { 'CONTENT_TYPE' => 'application/json' }

      expect(response).to have_http_status(:bad_request)
    end

    it 'answers a query string that is not text with the client error it always was' do
      post "#{user_session_path(locale: 'en')}?user[email]=%FF"

      expect(response).to have_http_status(:bad_request)
    end
  end

  describe 'the account a sign-in names' do
    def account_in(path = '/en/users/sign_in', **env)
      Rack::Attack::Request.new(Rack::MockRequest.env_for(path, method: 'POST', **env)).sign_in_email
    end

    it 'is read from a form, a query string and a json body alike' do
      form = { params: { user: { email: ' Victim@Example.com ' } } }
      json = { input: { user: { email: 'victim@example.com' } }.to_json, 'CONTENT_TYPE' => 'application/json' }

      expect([account_in(**form), account_in('/en/users/sign_in?user[email]=VICTIM@example.com'), account_in(**json)])
        .to all(eq('victim@example.com'))
    end

    it 'is nothing for a body that is not json, and does not raise' do
      expect(account_in(input: '{"user":', 'CONTENT_TYPE' => 'application/json')).to be_nil
    end

    it 'is nothing for a query string that is not text, and does not raise' do
      expect(account_in('/en/users/sign_in?user[email]=%FF')).to be_nil
    end

    it 'is nothing for an email that is a list or a hash' do
      list = account_in(params: { user: { email: %w[a@example.com] } })
      hash = account_in(params: { user: { email: { a: 'b' } } })

      expect([list, hash]).to all(be_nil)
    end
  end

  it 'keeps the locale of a sign-in it has already read the parameters of' do
    sign_in_attempt(path: '/uk/users/sign_in')

    expect(response.body).to include('lang="uk"')
  end

  describe 'password reset' do
    it 'lets a person ask a few times' do
      5.times { reset_attempt }

      expect(response).not_to have_http_status(:too_many_requests)
    end

    it 'stops a script asking for mail' do
      6.times { reset_attempt }

      expect(response).to have_http_status(:too_many_requests)
    end

    it 'only stops the address that asked' do
      6.times { reset_attempt }
      reset_attempt(ip: '203.0.113.11')

      expect(response).not_to have_http_status(:too_many_requests)
    end

    ['/en/users/password.json', '/en/users/password/', '/users/password', '/uk/users/password'].each do |path|
      it "stops a script behind #{path}" do
        6.times { reset_attempt(path: path) }

        expect(response).to have_http_status(:too_many_requests)
      end
    end
  end

  describe 'translation' do
    def translate_attempt(path: translate_management_posts_path(locale: 'en'), ip: '203.0.113.10')
      post path, env: { 'REMOTE_ADDR' => ip }
    end

    it 'lets an editor translate a few posts' do
      10.times { translate_attempt }

      expect(response).not_to have_http_status(:too_many_requests)
    end

    it 'stops a script spending the translation quota' do
      11.times { translate_attempt }

      expect(response).to have_http_status(:too_many_requests)
    end

    it 'only stops the address that asked' do
      11.times { translate_attempt }
      translate_attempt(ip: '203.0.113.11')

      expect(response).not_to have_http_status(:too_many_requests)
    end

    it 'does not count the pages that only look at a post' do
      11.times { get management_posts_path(locale: 'en'), env: { 'REMOTE_ADDR' => '203.0.113.10' } }
      translate_attempt

      expect(response).not_to have_http_status(:too_many_requests)
    end

    [
      '/en/management/posts/translate.json', '/en/management/posts/translate/', '/management/posts/translate',
      '/uk/management/posts/translate', '/en//management/posts/translate'
    ].each do |path|
      it "is one counter behind #{path}" do
        paths = [translate_management_posts_path(locale: 'en'), path]
        11.times { |n| translate_attempt(path: paths[n % 2]) }

        expect(response).to have_http_status(:too_many_requests)
      end
    end
  end

  describe 'search' do
    it 'lets the palette call it while somebody types' do
      60.times { get search_path(locale: 'en', format: :json), env: { 'REMOTE_ADDR' => '203.0.113.10' } }

      expect(response).not_to have_http_status(:too_many_requests)
    end

    it 'stops a script walking the full-text index' do
      61.times { get search_path(locale: 'en', format: :json), env: { 'REMOTE_ADDR' => '203.0.113.10' } }

      expect(response).to have_http_status(:too_many_requests)
    end

    it 'only stops the address that walked it' do
      61.times { get search_path(locale: 'en', format: :json), env: { 'REMOTE_ADDR' => '203.0.113.10' } }
      get search_path(locale: 'en', format: :json), env: { 'REMOTE_ADDR' => '203.0.113.11' }

      expect(response).not_to have_http_status(:too_many_requests)
    end

    ['/en/search', '/en/search.html', '/en/search/', '/search', '/uk/search.json'].each do |path|
      it "is one counter behind #{path}" do
        paths = ['/en/search.json', path]
        61.times { |n| get paths[n % 2], env: { 'REMOTE_ADDR' => '203.0.113.10' } }

        expect(response).to have_http_status(:too_many_requests)
      end
    end
  end

  describe 'everything else' do
    it 'lets a reader click through a whole site' do
      300.times { get robots_path, env: { 'REMOTE_ADDR' => '203.0.113.10' } }

      expect(response).not_to have_http_status(:too_many_requests)
    end

    it 'stops a crawler that never slows down' do
      301.times { get robots_path, env: { 'REMOTE_ADDR' => '203.0.113.10' } }

      expect(response).to have_http_status(:too_many_requests)
    end

    it 'only stops the address that crawled' do
      301.times { get robots_path, env: { 'REMOTE_ADDR' => '203.0.113.10' } }
      get robots_path, env: { 'REMOTE_ADDR' => '203.0.113.11' }

      expect(response).not_to have_http_status(:too_many_requests)
    end

    # The editor autosaves and re-renders its preview every couple of seconds.
    describe 'a signed-in editor' do
      before { sign_in create(:user, :admin) }

      it 'is not cut off by the backstop while writing in /management and its API' do
        paths = [management_posts_path(locale: 'en'), '/management/posts', api_tags_path(locale: 'en')]
        301.times { |n| get paths[n % paths.size], env: { 'REMOTE_ADDR' => '203.0.113.10' } }

        expect(response).not_to have_http_status(:too_many_requests)
      end

      it 'still counts toward the backstop on the public pages' do
        301.times { get robots_path, env: { 'REMOTE_ADDR' => '203.0.113.10' } }

        expect(response).to have_http_status(:too_many_requests)
      end
    end

    it 'still counts an anonymous request to /management' do
      301.times { get management_posts_path(locale: 'en'), env: { 'REMOTE_ADDR' => '203.0.113.10' } }

      expect(response).to have_http_status(:too_many_requests)
    end
  end
end
