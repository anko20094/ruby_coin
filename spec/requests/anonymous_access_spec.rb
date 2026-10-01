# frozen_string_literal: true

require 'rails_helper'

describe 'the admin and the API, signed out', type: :request do
  # Read from the router, so a new route is in the sweep without anyone listing it.
  def self.guarded
    Rails.application.routes.routes.filter_map do |route|
      path = route.path.spec.to_s

      [route.verb, route.format(locale: 'en', id: 1)] if path.include?('/management') || path.include?('/api/')
    end
  end

  it 'finds the writes as well as the reads' do
    expect(self.class.guarded.map(&:first)).to include('GET', 'POST', 'PATCH', 'PUT', 'DELETE')
  end

  guarded.each do |verb, path|
    it "sends #{verb} #{path} to sign in" do
      public_send(verb.downcase, path)

      expect(response).to redirect_to(%r{/users/sign_in\z})
    end
  end
end
