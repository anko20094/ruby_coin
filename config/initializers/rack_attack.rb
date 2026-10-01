# frozen_string_literal: true

# The throttles redesign_plan.md §2 promises. Nothing was in place: sign-in, the password
# reset and the search screen were all unmetered, and search is the only public endpoint that
# runs a full-text query per request.
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
  throttle('requests/ip', limit: 300, period: 5.minutes) do |request|
    request.ip unless request.path.match?(ASSET_PATHS)
  end

  # Answer in a way a person can act on, and tell a client how long to wait.
  self.throttled_responder = lambda do |request|
    match = request.env['rack.attack.match_data'] || {}
    retry_after = (match[:period] || 60).to_i

    [
      429,
      { 'content-type' => 'text/plain; charset=utf-8', 'retry-after' => retry_after.to_s },
      ["Too many requests. Try again in #{retry_after} seconds.\n"]
    ]
  end
end
