# frozen_string_literal: true

require 'vcr'

# https://github.com/vcr/vcr/issues/71
begin
  require 'zlib'
  require 'stringio'
  have_zlib = true
rescue LoadError
  have_zlib = false
end

VCR.configure do |c|
  {
    '<CHAT_GPT_KEY>' => Rails.application.credentials.chat_gpt_key
  }.each do |placeholder, value|
    c.filter_sensitive_data(placeholder) { value } if value.present?
  end

  c.before_record do |i|
    auth_headers = i.request.headers['Authorization']
    next if auth_headers.blank?

    i.request.headers['Authorization'] = auth_headers.map do |value|
      value.to_s.gsub(/\ABearer\s+\S+\z/, 'Bearer <CHAT_GPT_KEY>')
    end
  end

  c.before_record do |i|
    body = i.response.body
    next unless body.encoding == Encoding::ASCII_8BIT

    utf8_body = body.force_encoding('UTF-8')
    next unless utf8_body.valid_encoding?

    i.response.body = utf8_body
  end

  c.before_record(:ascii) do |i|
    break unless have_zlib

    enc = i.response.headers['Content-Encoding']
    if enc && Array(enc).first == 'gzip'
      i.response.body = Zlib::GzipReader
                        .new(StringIO.new(i.response.body), encoding: 'ASCII-8BIT').read
      i.response.update_content_length_header
      i.response.headers.delete 'Content-Encoding'
    end
  end
  c.cassette_library_dir = Rails.root.join('spec', 'vcr')
  c.hook_into :webmock
  c.configure_rspec_metadata!

  c.ignore_localhost = true
  c.debug_logger = File.open(Rails.root.join('log', 'vcr.log'), 'w')
  c.allow_http_connections_when_no_cassette = false
end

if ENV['FIND_UNUSED_VCR_CASSETTES']
  USED_CASSETTES = Set.new

  module CassetteReporter
    def insert_cassette(name, options = {})
      USED_CASSETTES << VCR::Cassette.new(name, options).file

      super
    end
  end

  VCR.extend(CassetteReporter)
end

RSpec.configure do |config|
  # Report about unused cassettes
  config.after(:suite) do
    if ENV['FIND_UNUSED_VCR_CASSETTES']
      all_cassettes = Dir[File.join(VCR.configuration.cassette_library_dir, '**/*.yml')].map do |d|
        File.expand_path(d)
      end
      all_cassettes - USED_CASSETTES.to_a
    end
  end
end
