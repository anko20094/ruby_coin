# frozen_string_literal: true

RSpec.shared_context 'when carrierwave cleanup' do
  after { SpecUploads.empty! }
end
