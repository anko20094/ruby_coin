# frozen_string_literal: true

# Throttles for sign-in, the password reset, AI translation and search — search being the only
# public endpoint that runs a full-text query per request.
#
# Deliberately generous. This is a personal site, not a target — the point is that a script
# cannot sit on the sign-in form all night, not that a reader has to think about how fast they
# click.
class Rack::Attack
  # Assets are served by the same process in some deployments; they are not what needs metering.
  ASSET_PATHS = %r{\A/(assets|og|packs)/}

  # Rack::Attack has already normalised slashes by now; the locale prefix and the format suffix
  # are the router's, so a route is matched by its tail and any suffix it answers under.
  FORMAT = %r{(?:\.[^/.?]+)?\z}
  SIGN_IN = %r{/users/sign_in#{FORMAT}}
  PASSWORD = %r{/users/password#{FORMAT}}
  SEARCH = %r{/search#{FORMAT}}
  TRANSLATE = %r{/management/posts/translate#{FORMAT}}
  # The admin and the editor's API, under a locale or none.
  LOCALE = %r{\A/(#{I18n.available_locales.join('|')})(?=/|\z)}
  BEHIND_SIGN_IN = %r{\A(?:/(?:#{I18n.available_locales.join('|')}))?/(?:management|api)(?:[/.]|\z)}

  # Its own store: the app's file store only drops a counter when that exact key is read again,
  # and a time-bucketed key never is. A memory store prunes itself and writes nothing to disk.
  cache.store = ActiveSupport::Cache::MemoryStore.new

  class Request
    # The address Devise authenticates, read the way Devise reads it (query over body, JSON
    # included). Anything that is not a plain string is not an account.
    def sign_in_email
      user = ActionDispatch::Request.new(env).parameters[:user]
      email = user[:email] if user.is_a?(Hash)
      email.downcase.strip.presence if email.is_a?(String)
    rescue ActionController::BadRequest, ActionDispatch::Http::Parameters::ParseError
      nil
    end

    # Warden runs before this middleware, so the session is already read; nothing is asked of
    # the database that the controller would not ask anyway.
    def signed_in?
      warden = env['warden']
      warden.present? && warden.authenticated?(:user)
    end

    # The admin is a signed-in editor, not a crawler.
    def admin? = path.match?(BEHIND_SIGN_IN) && signed_in?

    def path_locale = path[LOCALE, 1] || I18n.default_locale
  end

  # Off while developing and in the suite unless a spec asks for it: a rate limiter that fires
  # on the twentieth page of a click-through is a worse bug than no rate limiter.
  self.enabled = !Rails.env.local?

  safelist('assets') { |request| request.path.match?(ASSET_PATHS) }

  # Credential stuffing. Per IP and, separately, per account — an attacker rotating IPs against
  # one address is the case the first rule misses.
  throttle('sign-in/ip', limit: 10, period: 1.minute) do |request|
    request.ip if request.post? && request.path.match?(SIGN_IN)
  end

  throttle('sign-in/email', limit: 10, period: 20.minutes) do |request|
    request.sign_in_email if request.post? && request.path.match?(SIGN_IN)
  end

  throttle('password-reset/ip', limit: 5, period: 20.minutes) do |request|
    request.ip if request.post? && request.path.match?(PASSWORD)
  end

  # The one public endpoint that costs a full-text query, and the palette calls it while the
  # reader types.
  throttle('search/ip', limit: 60, period: 1.minute) do |request|
    request.ip if request.path.match?(SEARCH)
  end

  # An OpenAI call per request, on the site's bill.
  throttle('translate/ip', limit: 10, period: 1.minute) do |request|
    request.ip if request.post? && request.path.match?(TRANSLATE)
  end

  # A backstop for everything else. A reader clicking through the whole site never comes close.
  # A signed-in editor in /management does: the editor autosaves and re-renders its preview
  # every couple of seconds, so an hour of writing is well past 300 requests in five minutes.
  # Those requests are behind a password, and the sign-in in front of them has its own limits;
  # an anonymous request to the same paths still counts.
  throttle('requests/ip', limit: 300, period: 5.minutes) do |request|
    request.ip unless request.path.match?(ASSET_PATHS) || request.admin?
  end

  # Answer in a way a person can act on, in the language of the page they asked for, and tell a
  # client how long to wait.
  self.throttled_responder = lambda do |request|
    match = request.env['rack.attack.match_data'] || {}
    retry_after = (match[:period] || 60).to_i
    message = I18n.t('throttled', count: retry_after, locale: request.path_locale)

    [
      429,
      { 'content-type' => 'text/plain; charset=utf-8', 'retry-after' => retry_after.to_s },
      ["#{message}\n"]
    ]
  end
end
