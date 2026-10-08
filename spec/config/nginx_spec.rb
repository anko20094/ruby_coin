# frozen_string_literal: true

require 'rails_helper'

# nginx answers everything under public/ itself, so the vhost decides how it is compressed and
# cached. There is no nginx to run here, so this reads the file.
RSpec.describe 'config/nginx.conf' do # rubocop:disable RSpec/DescribeClass
  let(:conf) { Rails.root.join('config', 'nginx.conf').read }

  def location(prefix) = conf[/location #{Regexp.escape(prefix)} \{([^}]*)\}/, 1]

  it 'compresses the text it serves out of public/' do
    expect(conf).to match(/^\s*gzip on;/)
    expect(conf[/gzip_types ([^;]+);/, 1].split).to include('text/css', 'application/javascript', 'image/svg+xml')
  end

  it 'lets browsers keep digested assets for a year' do
    expect(location('^~ /assets/')).to include('max-age=31536000', 'immutable')
  end

  it 'gives share cards and uploads, which keep their names, a short lifetime' do
    expect(location('~ ^/(og|uploads)/')).to include('max-age=3600')
  end

  it 'proxies no WebSocket endpoint, because the app mounts none' do
    expect(conf).not_to match(%r{location\s+/cable})
    expect(conf).not_to include('Upgrade')
  end
end
