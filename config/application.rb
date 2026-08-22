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

    config.i18n.available_locales = [:en, :uk]
    config.i18n.default_locale = :uk
    config.time_zone = 'Europe/Kyiv'
    # config.active_record.default_timezone = :local
    config.active_job.queue_adapter = :sidekiq

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
