# frozen_string_literal: true

# The test environment lets an exception out of the request; this shows the page a visitor gets.
RSpec.shared_context 'when errors render as pages' do
  around do |example|
    config = Rails.application.env_config
    was = config.values_at('action_dispatch.show_exceptions', 'action_dispatch.show_detailed_exceptions')

    config['action_dispatch.show_exceptions'] = :all
    config['action_dispatch.show_detailed_exceptions'] = false

    example.run
  ensure
    config['action_dispatch.show_exceptions'], config['action_dispatch.show_detailed_exceptions'] = was
  end
end
