# frozen_string_literal: true

require 'active_support/core_ext/integer/time'

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests. (cache_classes is the name Rails deprecated.)
  config.enable_reloading = false

  # Eager load code on boot. This eager loads most of Rails and
  # your application in memory, allowing both threaded web servers
  # and those relying on copy on write to perform better.
  # Rake tasks automatically ignore this option for performance.
  config.eager_load = true

  # Full error reports are disabled and caching is turned on.
  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true

  # Ensures that a master key has been made available in either ENV["RAILS_MASTER_KEY"]
  # or in config/master.key. This key is used to decrypt credentials (and other encrypted files).
  # config.require_master_key = true

  # Rails serves /public itself unless this is switched off, and it was serving digested
  # assets with no expiry at all — every visitor re-downloaded every font and stylesheet on
  # every visit. Digested filenames change when the content does, so a year is safe.
  config.public_file_server.headers = {
    'cache-control' => "public, max-age=#{1.year.to_i}, immutable"
  }

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Specifies the header that your server uses for sending files.
  # config.action_dispatch.x_sendfile_header = "X-Sendfile" # for Apache
  # config.action_dispatch.x_sendfile_header = "X-Accel-Redirect" # for NGINX

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :production

  # Off by default because this app has been deployed over plain HTTP and turning it on
  # against a server without TLS makes the site unreachable rather than secure. Set FORCE_SSL
  # in the environment once the certificate is in place — that is the whole switch, and it
  # brings HSTS and secure cookies with it.
  config.force_ssl = ENV['FORCE_SSL'].present?
  config.assume_ssl = ENV['FORCE_SSL'].present?

  # Include generic and useful information about system operation, but avoid logging too much
  # information to avoid inadvertent exposure of personally identifiable information (PII).
  config.log_level = :info

  # Prepend all log lines with the following tags.
  config.log_tags = [:request_id]

  # There was no cache store configured, so `perform_caching = true` above cached into the
  # null store and every `cache` block in a view was a no-op. The file store lives under
  # tmp/cache, which Capistrano already keeps as a shared linked directory, so it survives a
  # deploy and is shared across Puma workers.
  config.cache_store = :file_store, Rails.root.join('tmp', 'cache')

  # Use a real queuing backend for Active Job (and separate queues per environment).
  # config.active_job.queue_adapter     = :resque
  # config.active_job.queue_name_prefix = "ruby_coin_production"

  config.action_mailer.perform_caching = false

  # There was no delivery configuration at all, and Devise's :recoverable module is enabled —
  # so a password reset in production raised "Missing host to link to!" before it ever got as
  # far as trying to send. Reads the environment so no credentials live in the repo; with
  # SMTP_ADDRESS unset it falls back to logging the mail instead of pretending to send it.
  config.action_mailer.default_url_options = { host: ENV.fetch('APP_HOST', 'rubyco.in'), protocol: 'https' }
  config.action_mailer.perform_deliveries = true
  config.action_mailer.raise_delivery_errors = true

  if ENV['SMTP_ADDRESS'].present?
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.smtp_settings = {
      address: ENV.fetch('SMTP_ADDRESS'),
      port: ENV.fetch('SMTP_PORT', 587).to_i,
      user_name: ENV.fetch('SMTP_USERNAME', nil),
      password: ENV.fetch('SMTP_PASSWORD', nil),
      authentication: :plain,
      enable_starttls_auto: true
    }
  else
    config.action_mailer.delivery_method = :test
  end

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Use default logging formatter so that PID and timestamp are not suppressed.
  config.log_formatter = Logger::Formatter.new

  # Use a different logger for distributed setups.
  # require "syslog/logger"
  # config.logger = ActiveSupport::TaggedLogging.new(Syslog::Logger.new "app-name")

  if ENV['RAILS_LOG_TO_STDOUT'].present?
    logger           = ActiveSupport::Logger.new($stdout)
    logger.formatter = config.log_formatter
    config.logger    = ActiveSupport::TaggedLogging.new(logger)
  end

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false
end
