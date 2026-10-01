# frozen_string_literal: true

require 'rails_helper'

# The switcher is in the nav of every themed page, so a query string it cannot digest takes the
# page down with it. ?controller= and ?action= are what scanners send; ?host= is what a phisher does.
describe 'the language switcher', type: :request do
  include_context 'when the cases are imported'
  include_context 'when the cv is imported'

  def switcher_hrefs
    response.body.scan(/class="rc-nav__locale[^"]*"[^>]*href="([^"]*)"/).flatten
  end

  paths = %w[/uk?action=a /en?controller=a /en/journal?controller=a /en/team/danyil?controller=a /en/faq?_recall=a]

  paths.each do |path|
    it "renders #{path}" do
      get path

      expect(response).to have_http_status(:success)
    end
  end

  it 'never leaves the site, whatever the address says about hosts' do
    get '/en/faq?host=evil.example&protocol=https&port=8080'

    expect(switcher_hrefs).to all(start_with('/'))
    expect(switcher_hrefs.first).to start_with('/uk/faq?')
  end
end
