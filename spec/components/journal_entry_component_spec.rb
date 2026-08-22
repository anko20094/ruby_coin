# frozen_string_literal: true

require 'rails_helper'

RSpec.describe JournalEntryComponent, type: :component do
  include_context 'when carrierwave cleanup'

  around { |example| I18n.with_locale(:en) { example.run } }

  let(:post_record) { create(:post, status: 'active', entry_number: 7, created_at: Time.zone.local(2026, 5, 21)) }

  it 'is a single link, so keyboard and middle-click work' do
    render_inline(described_class.new(post: post_record))

    expect(page).to have_css("a.jn-entry[href='#{Rails.application.routes.url_helpers.post_path(post_record,
                                                                                                locale: :en)}']")
  end

  it 'prints the stored number and a dot-separated date' do
    render_inline(described_class.new(post: post_record))

    expect(page).to have_css('.jn-entry__number', text: '#007')
    expect(page).to have_css('.jn-entry__date', text: '2026·05·21')
  end

  it 'opens the list with the strong rule only on the first row' do
    render_inline(described_class.new(post: post_record, first: true))
    expect(page).to have_css('.jn-entry--first')

    render_inline(described_class.new(post: post_record))
    expect(page).to have_no_css('.jn-entry--first')
  end

  it 'badges a recent entry and leaves an old one alone' do
    render_inline(described_class.new(post: create(:post, status: 'active')))
    expect(page).to have_css('.jn-entry__badge', text: 'NEW')

    render_inline(described_class.new(post: post_record))
    expect(page).to have_no_css('.jn-entry__badge')
  end

  it 'puts the author, the reading time and the tags in the right-hand column' do
    post_record.tags << create(:tag, title: 'rails')

    render_inline(described_class.new(post: post_record))

    expect(page).to have_css('.jn-entry__meta', text: post_record.user.nickname)
    expect(page).to have_css('.jn-entry__meta', text: '1 min')
    expect(page).to have_css('.jn-entry__tags', text: '#rails')
  end
end
