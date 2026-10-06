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

  it 'titles the row with an h2, or an h3 when it sits under a heading of its own' do
    render_inline(described_class.new(post: post_record))
    expect(page).to have_css('h2.jn-entry__title')

    render_inline(described_class.new(post: post_record, heading: :h3))
    expect(page).to have_css('h3.jn-entry__title')
  end

  it 'names nothing for a view transition until the post has an id' do
    render_inline(described_class.new(post: build(:post, created_at: Time.zone.local(2026, 5, 21))))

    expect(page).to have_no_css('[data-vt-name], [style*="view-transition-name"]')
  end

  describe 'the preview card' do
    it 'is drawn with the row, hidden from assistive tech, with the lead, the minutes and the tags' do
      post_record.update!(subtitle: 'A lead that says what the entry is about.', tags: [create(:tag, title: 'rails')])

      render_inline(described_class.new(post: post_record))

      card = page.find('.jn-preview[aria-hidden="true"][data-controller="entry-preview"]', visible: :all)
      expect(card).to have_css(".jn-preview__lead#jn-lead-#{post_record.id}",
                               text: 'A lead that says what the entry is about.', visible: :all)
      expect(card).to have_css('.jn-preview__meta', text: '1 min · #rails', visible: :all)
      expect(card).to have_css('.jn-preview__thumb', visible: :all)
    end

    it 'cuts a long lead at a word' do
      post_record.update!(subtitle: "#{'word ' * 60}end")

      render_inline(described_class.new(post: post_record))

      lead = page.find('.jn-preview__lead', visible: :all).text
      expect(lead.length).to be <= described_class::LEAD_LIMIT
      expect(lead).to end_with('word...')
    end
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

  it 'leads with a thumbnail: the cover, or the post’s stone when it has none' do
    render_inline(described_class.new(post: post_record))
    expect(page).to have_css('.jn-entry__thumb img')

    # A cover is required; a post goes without one when its file has gone missing.
    uncovered = create(:post, status: 'active')
    uncovered.update_columns(photo: nil)

    render_inline(described_class.new(post: uncovered.reload))
    expect(page).to have_css('.jn-entry__thumb .rc-cover-gem svg.rc-gem')
  end

  it 'puts the author, the reading time and the tags in the right-hand column' do
    post_record.tags << create(:tag, title: 'rails')

    render_inline(described_class.new(post: post_record))

    expect(page).to have_css('.jn-entry__meta', text: post_record.user.nickname)
    expect(page).to have_css('.jn-entry__meta', text: '1 min')
    expect(page).to have_css('.jn-entry__tags', text: '#rails')
  end
end
