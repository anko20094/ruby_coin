# frozen_string_literal: true

module BrowserHeaders
  USER_AGENT = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 ' \
               '(KHTML, like Gecko) Chrome/140.0 Safari/537.36'

  def browser_headers(extra = {})
    { 'HTTP_USER_AGENT' => USER_AGENT }.merge(extra)
  end
end

RSpec.configure do |config|
  config.include BrowserHeaders, type: :request
end
