# frozen_string_literal: true

module SpecUploads
  # CarrierWave.root is Rails.public_path; only the uploaders' own root is the per-process scratch directory.
  def self.empty!
    root = Pathname(CarrierWave::Uploader::Base.root.to_s)
    raise ArgumentError, "refusing to empty #{root}" unless root.to_s.start_with?(Rails.root.join('tmp').to_s)

    FileUtils.rm_rf(root)
  end
end

RSpec.configure do |config|
  config.before(:suite) { SpecUploads.empty! }
  config.after(:suite) { SpecUploads.empty! }
end
