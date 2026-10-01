# frozen_string_literal: true

require 'rails_helper'
require 'rake'
load Rails.root.join('lib', 'tasks', 'og_cards.rake')

# The cards are PNGs committed beside a digest of the text they were drawn from. A case whose
# title, tagline or first figure changes after `rake og:cards` unfurls the old one in Telegram
# and LinkedIn, which is where most readers meet this site, and nothing else on the site would
# notice.
RSpec.describe OgCards do
  include_context 'when the cases are imported'

  let(:recorded) { JSON.parse(described_class::MANIFEST.read) }

  it 'drew every card from the text the pages print today' do
    stale = described_class.digests.reject { |name, digest| recorded[name] == digest }.keys

    expect(stale).to be_empty,
                     "stale cards #{stale.join(', ')}: import the cases, then `rake og:cards`, commit public/og"
  end

  it 'records a card for every case in both languages and nothing else' do
    expected = Case.pluck(:slug).product(I18nExtended::AVAILABLE_LOCALES).map { |slug, locale| "#{slug}-#{locale}" }

    expect(recorded.keys).to match_array(expected + I18nExtended::AVAILABLE_LOCALES.map { |locale| "site-#{locale}" })
  end

  it 'has the image for every card it recorded' do
    missing = recorded.keys.reject { |name| described_class::OUTPUT_DIR.join("#{name}.png").exist? }

    expect(missing).to be_empty
  end
end
