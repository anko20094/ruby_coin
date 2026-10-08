# frozen_string_literal: true

require 'rails_helper'

describe HexRingsComponent, type: :component do
  it 'draws the four rings, hidden from assistive technology' do
    render_inline(described_class.new(css: 'hm-hero__rings'))

    expect(page).to have_css('svg.rc-rings.hm-hero__rings[aria-hidden="true"][focusable="false"]')
    expect(page.all('svg.rc-rings polygon').pluck(:points)).to eq(described_class::RINGS)
  end

  it 'takes no placement class when given none' do
    render_inline(described_class.new)

    expect(page.find('svg')[:class]).to eq('rc-rings')
  end
end
