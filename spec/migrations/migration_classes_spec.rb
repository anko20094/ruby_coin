# frozen_string_literal: true

require 'rails_helper'

# CI builds the database from schema.rb and never loads a migration, so a class the migrator
# cannot find only shows up on the first real deploy.
RSpec.describe 'db/migrate' do # rubocop:disable RSpec/DescribeClass
  let(:migrations) { ActiveRecord::Base.connection_pool.migration_context.migrations }

  it 'defines, in every file, the class the migrator will look for' do
    expect(migrations).not_to be_empty

    declared = migrations.to_h { |migration| [migration.name, File.read(migration.filename)[/^class (\w+)/, 1]] }

    expect(declared.reject { |expected, actual| expected == actual }).to eq({})
  end
end
