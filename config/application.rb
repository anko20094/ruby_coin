# frozen_string_literal: true

require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module RubyCoin
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    config.exceptions_app = routes

    # Nothing on the wire was compressed: no Deflater in the stack, and the deployed nginx
    # vhost does not gzip either. The theme's stylesheet alone is 42 KB uncompressed and 9 KB
    # gzipped, and on a 3G connection that difference is most of a second. Inserted before
    # ActionDispatch::Static so files served out of public/ are compressed too.
    config.middleware.insert_before ActionDispatch::Static, Rack::Deflater

    config.i18n.available_locales = [:en, :uk]
    config.i18n.default_locale = :uk
    config.time_zone = 'Europe/Kyiv'
    # config.active_record.default_timezone = :local
    # In-process, because the only jobs this app enqueues are Active Storage's own analyse
    # and purge housekeeping. It used to say :sidekiq — with no Sidekiq worker in the Procfile
    # or in any deploy file, so those jobs were queued into nothing and never ran. Solid Queue
    # is the intended destination (redesign_plan.md §2); it needs a worker process and a
    # systemd unit on the server, so it is a deploy change rather than a code change.
    config.active_job.queue_adapter = :async

    config.generators do |g|
      g.test_framework :rspec
      g.fixture_replacement :factory_bot, dir: 'spec/factories'
    end
    # Component previews live beside the specs, not in the test/ tree the app
    # does not have.
    config.view_component.previews.paths = [Rails.root.join('spec', 'components', 'previews').to_s]
    config.view_component.previews.default_layout = 'component_preview'
  end
end

# "cv" is an abbreviation everywhere it appears on this site: CVProfile, CVBlock, CV::Importer,
# Management::CVBlocksController. One acronym covers all of them, because both inflectors that
# matter here go through camelize — Rails' autoloader inflector and the one routing uses to
# turn "management/cv_blocks" into a controller class.
#
# It has to be declared here rather than in config/initializers/inflections.rb: initializers
# run after the autoloader has already worked out the constant names for app/models.
ActiveSupport::Inflector.inflections(:en) do |inflect|
  inflect.acronym 'CV'
end
