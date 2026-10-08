# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('db', 'migrate', '20260824190000_add_search_and_listing_indexes')

RSpec.describe AddSearchAndListingIndexes do
  let(:connection) { ActiveRecord::Base.connection }

  def migrate(direction)
    ActiveRecord::Migration.suppress_messages { described_class.new.migrate(direction) }
  end

  def insert_translations(*pairs) = PostTranslation.insert_all!(pairs.map { |post_id, locale| { post_id:, locale: } })

  def unique_index? = connection.index_exists?(:post_translations, %i[post_id locale], unique: true)

  before { migrate(:down) }

  after { PostTranslation.reset_column_information }

  it 'adds the unique index when every post has one row per language' do
    insert_translations([1, 'en'], [1, 'uk'], [2, 'en'])

    migrate(:up)

    expect(unique_index?).to be(true)
  end

  it 'refuses, naming the pair, when a post has two rows for one language' do
    insert_translations([7, 'uk'], [7, 'uk'], [8, 'en'])

    expect { migrate(:up) }.to raise_error(ActiveRecord::MigrationError, %r{7/uk \(2 rows\)})
    expect(unique_index?).to be(false)
    expect(PostTranslation.where(post_id: 7).count).to eq(2)
  end
end
