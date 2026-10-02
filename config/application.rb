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

    # Text only: fonts, JPEG and PNG are compressed already. Behind the deployed nginx the files
    # in public/ never reach this, and config/nginx.conf does their compressing.
    config.middleware.insert_before ActionDispatch::Static, Rack::Deflater, include: %w[
      text/html text/css text/plain text/javascript application/javascript application/json
      application/atom+xml application/xml image/svg+xml
    ]

    # Nothing opens a cable connection, and the railtie would still mount /cable.
    config.action_cable.mount_path = nil

    # The one list of locales: the routes and I18nExtended read it from here.
    config.i18n.available_locales = %i[en uk]
    config.i18n.default_locale = :uk
    config.time_zone = 'Europe/Kyiv'
    # config.active_record.default_timezone = :local
    # In-process: the only jobs are Active Storage's analyse/purge housekeeping. Solid Queue
    # is the goal (docs/decisions.md), but it needs a worker and a systemd unit — a deploy change.
    config.active_job.queue_adapter = :async

    # ImageMagick, not libvips. Rails 8 defaults to :vips, and this app has never needed it:
    # post covers go through CarrierWave and MiniMagick, so ImageMagick is already a hard
    # dependency of the deploy and libvips would be a second one for the same job. Left on the
    # default, an editor's image upload failed to make a variant and quietly served the
    # untouched original — several megabytes into a 760px measure.
    config.active_storage.variant_processor = :mini_magick

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

# "cv" is an abbreviation everywhere it appears on this site: Person::CV, CVController. One
# acronym covers all of them, because both inflectors that matter here go through camelize —
# Rails' autoloader inflector and the one routing uses to turn "cv" into a controller class.
#
# It has to be declared here rather than in config/initializers/inflections.rb: initializers
# run after the autoloader has already worked out the constant names for app/models.
ActiveSupport::Inflector.inflections(:en) do |inflect|
  inflect.acronym 'CV'
end
