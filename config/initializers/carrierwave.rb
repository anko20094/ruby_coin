# frozen_string_literal: true

CarrierWave.configure do |config|
  config.asset_host = ActionController::Base.asset_host

  if Rails.env.test?
    config.storage = :file
    config.enable_processing = false
    # Per process, so two runs in one checkout do not empty each other's files mid-example.
    config.root = Rails.root.join('tmp', 'spec', 'uploads', Process.pid.to_s)
  end
end
