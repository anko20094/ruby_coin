# frozen_string_literal: true

require 'rails_helper'

# The posts list's filter tabs and the sidebar print the same per-status counts.
RSpec.describe 'the post counts on the posts list' do
  around do |example|
    was = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    example.run
  ensure
    Rails.cache = was
  end

  before do
    sign_in create(:user, role: :admin)
    create_list(:post, 2)
  end

  it 'are read once for the tabs and the sidebar together' do
    statements = []
    collect = ->(*, payload) { statements << payload[:sql] if payload[:sql].include?('GROUP BY "posts"."status"') }

    ActiveSupport::Notifications.subscribed(collect, 'sql.active_record') { get '/en/management/posts' }

    expect(response).to have_http_status(:ok)
    expect(statements.size).to eq(1)
  end
end
