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

  # The address every absolute URL a page prints is built from — canonical, share cards, the
  # sitemap, the feed — in place of the Host header a client chose to send.
  config.x.canonical_url_options = { host: ENV['APP_HOST'].presence || 'rubyco.in', protocol: 'https' }

  # Devise's :recoverable builds a reset link, which needs a host. Credentials come from the
  # environment so none live in the repo; with SMTP_ADDRESS unset the mail is written to
  # tmp/mails rather than sent. Links are https whatever FORCE_SSL says: the vhost in
  # config/nginx.conf redirects plain HTTP to it. MAILER_FROM sets the sender of every mail
  # (default no-reply@rubyco.in).
  config.action_mailer.default_url_options = { host: ENV['APP_HOST'].presence || 'rubyco.in', protocol: 'https' }
  config.action_mailer.perform_deliveries = true
  config.action_mailer.raise_delivery_errors = true

  if ENV['SMTP_ADDRESS'].present?
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.smtp_settings = {
      address: ENV.fetch('SMTP_ADDRESS'),
      port: (ENV['SMTP_PORT'].presence || 587).to_i,
      user_name: ENV['SMTP_USERNAME'].presence,
      password: ENV['SMTP_PASSWORD'].presence,
      authentication: :plain,
      enable_starttls_auto: true
    }
  else
    config.action_mailer.delivery_method = :file
    config.action_mailer.file_settings = { location: Rails.root.join('tmp', 'mails').to_s }
  end

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
