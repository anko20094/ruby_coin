# frozen_string_literal: true

# Ahoy stopped counting bots, and to the browser gem a request with no User-Agent is a bot —
# which is every rack-test request. A spec that stands in for a person with a browser says so.
module BrowserHeaders
  USER_AGENT = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 ' \
               '(KHTML, like Gecko) Chrome/140.0 Safari/537.36'

  def browser_headers(extra = {})
    { 'HTTP_USER_AGENT' => USER_AGENT }.merge(extra)
  end
end

RSpec.configure do |config|
  config.include BrowserHeaders, type: :request
  config.include BrowserHeaders, type: :controller

  # Controller specs go through the controller directly, so set it on the request object.
  config.before(type: :controller) do
    request.headers['User-Agent'] = BrowserHeaders::USER_AGENT if respond_to?(:request) && request
  end
end
