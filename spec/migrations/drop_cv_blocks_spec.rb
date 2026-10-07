# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('db', 'migrate', '20261002120000_drop_cv_blocks')

RSpec.describe DropCVBlocks do
  let(:connection) { ActiveRecord::Base.connection }

  def migrate(direction)
    ActiveRecord::Migration.suppress_messages { described_class.new.migrate(direction) }
  end

  it 'leaves no cv_blocks table, which nothing reads since the CV is YAML' do
    expect(connection.table_exists?(:cv_blocks)).to be(false)
  end

  it 'puts the table back as it was on the way down' do
    migrate(:down)

    timestamp = 'timestamp(6) without time zone'
    expect(connection.columns(:cv_blocks).to_h { |column| [column.name, [column.sql_type, column.null]] }).to eq(
      'id' => ['bigint', false], 'case_slugs' => ['jsonb', false], 'created_at' => [timestamp, false],
      'kind' => ['character varying', false], 'payload' => ['jsonb', false], 'position' => ['integer', false],
      'updated_at' => [timestamp, false]
    )
    expect(connection.index_exists?(:cv_blocks, %i[kind position])).to be(true)
  ensure
    migrate(:up) if connection.table_exists?(:cv_blocks)
  end
end
