# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BaseService do
  it 'hands positional and keyword arguments to the instance and returns what #call returns' do
    service = Class.new(described_class) do
      def initialize(value, scale:)
        super()
        @value = value
        @scale = scale
      end

      def call = @value * @scale
    end

    expect(service.call(2, scale: 3)).to eq(6)
  end

  it 'refuses a service that never defined #call instead of answering nil' do
    expect { Class.new(described_class).call }.to raise_error(NotImplementedError)
  end
end
