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

  # The app's own cache in production — the file store under a shared directory, so two Puma
  # workers count the same request once. A memory store while developing, because the
  # development cache is the null store and a counter that never increments never throttles.
  cache.store =
    Rails.env.local? ? ActiveSupport::Cache::MemoryStore.new : Rails.cache

  # Off while developing and in the suite unless a spec asks for it: a rate limiter that fires
  # on the twentieth page of a click-through is a worse bug than no rate limiter.
  self.enabled = !Rails.env.local?

  safelist('assets') { |request| request.path.match?(ASSET_PATHS) }

  # Credential stuffing. Per IP and, separately, per account — an attacker rotating IPs against
  # one address is the case the first rule misses.
  throttle('sign-in/ip', limit: 10, period: 1.minute) do |request|
    request.ip if request.post? && request.path.end_with?('/users/sign_in')
  end

  throttle('sign-in/email', limit: 10, period: 20.minutes) do |request|
    next unless request.post? && request.path.end_with?('/users/sign_in')

    request.params.dig('user', 'email').to_s.downcase.strip.presence
  end

  throttle('password-reset/ip', limit: 5, period: 20.minutes) do |request|
    request.ip if request.post? && request.path.include?('/users/password')
  end

  # The one public endpoint that costs a full-text query, and the palette calls it while the
  # reader types.
  throttle('search/ip', limit: 60, period: 1.minute) do |request|
    request.ip if request.path.end_with?('/search', '/search.json')
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
