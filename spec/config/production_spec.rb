# frozen_string_literal: true

require 'json'
require 'open3'
require 'rails_helper'

# Boots the application the way the server does and reads back what it configured. The
# environment files are not loaded in test, so nothing else sees them.
RSpec.describe 'the production environment' do # rubocop:disable RSpec/DescribeClass
  probe = <<~RUBY
    require 'json'
    deflater = Rails.application.middleware.find { |middleware| middleware.klass == Rack::Deflater }
    puts JSON.generate(
      delivery_method: ActionMailer::Base.delivery_method,
      mail_location: ActionMailer::Base.file_settings[:location],
      mail_protocol: ActionMailer::Base.default_url_options[:protocol],
      cable_routes: Rails.application.routes.routes.map { |route| route.path.spec.to_s }.grep(%r{/cable}),
      compressed: deflater.args.first[:include]
    )
  RUBY

  launch = lambda do |env|
    variables = {
      'RAILS_ENV' => 'production', 'SECRET_KEY_BASE' => 'unused', 'FORCE_SSL' => nil, 'SMTP_ADDRESS' => nil,
      'DATABASE_URL' => 'postgresql://nobody@127.0.0.1:1/none'
    }
    output, = Open3.capture2e(variables.merge(env.transform_keys(&:to_s)), 'bin/rails', 'runner', probe,
                              chdir: Rails.root.to_s)
    JSON.parse(output.lines.last)
  end

  # One boot per environment, however many examples read it.
  boots = Hash.new { |memo, env| memo[env] = launch.call(env) }
  define_method(:boot) { |**env| boots[env] }

  context 'with no mail relay and no TLS configured' do
    let(:config) { boot }

    it 'writes mail to disk instead of dropping it into an in-memory array' do
      expect(config['delivery_method']).to eq('file')
      expect(config['mail_location']).to end_with('tmp/mails')
    end

    it 'links with https, which is what the vhost serves' do
      expect(config['mail_protocol']).to eq('https')
    end

    it 'mounts no cable endpoint, internal routes included' do
      expect(config['cable_routes']).to eq([])
    end

    it 'compresses text and not the formats that are compressed already' do
      expect(config['compressed']).to include('text/html', 'text/css', 'application/json')
      expect(config['compressed']).not_to include('font/woff2', 'image/jpeg', 'image/png')
    end
  end

  context 'with FORCE_SSL and an SMTP relay' do
    let(:config) { boot('FORCE_SSL' => '1', 'SMTP_ADDRESS' => 'smtp.example.com') }

    it 'links with https and sends through the relay' do
      expect(config['mail_protocol']).to eq('https')
      expect(config['delivery_method']).to eq('smtp')
    end
  end
end
