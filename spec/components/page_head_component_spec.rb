# frozen_string_literal: true

require 'rails_helper'

describe PageHeadComponent, type: :component do
  it 'opens the page on a scene with the title and its ruby mark' do
    render_inline(described_class.new(title: 'Journal', uid: 'spec'))

    expect(page).to have_css('header.rc-scene.rc-pagehead h1', text: 'Journal ·')
    expect(page).to have_css('h1 .rc-mark', text: '·')
  end

  it 'draws the anchor gem with its rings' do
    render_inline(described_class.new(title: 'Journal', uid: 'spec'))

    expect(page).to have_css('.rc-pagehead__gem svg.rc-rings')
    expect(page).to have_css('.rc-pagehead__gem svg.rc-gem--anchor')
  end

  it 'leads with a pill when given an eyebrow and a badge' do
    render_inline(described_class.new(title: 'Journal', uid: 'spec', eyebrow: 'notes', badge: '22'))

    expect(page).to have_css('p.rc-eyebrow .rc-eyebrow__badge', text: '22')
    expect(page).to have_css('p.rc-eyebrow', text: 'notes')
  end

  it 'leaves the pill and the lede out when there are none' do
    render_inline(described_class.new(title: 'Journal', uid: 'spec'))

    expect(page).to have_no_css('.rc-eyebrow')
    expect(page).to have_no_css('.rc-pagehead__lede')
  end

  it 'puts its content under the lede, inside the scene' do
    render_inline(described_class.new(title: 'Search', uid: 'spec', lede: 'Find it')) { 'the field' }

    expect(page).to have_css('.rc-pagehead__lede', text: 'Find it')
    expect(page).to have_css('.rc-scene .rc-pagehead__extra', text: 'the field')
  end
end
