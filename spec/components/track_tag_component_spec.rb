# frozen_string_literal: true

require 'rails_helper'

describe TrackTagComponent, type: :component do
  it 'colours the label by tone' do
    render_inline(described_class.new(label: 'in plain words', tone: :ruby))

    expect(page).to have_css('.rc-track.rc-track--ruby', text: 'in plain words')
  end

  it 'renders the label as a heading when asked' do
    render_inline(described_class.new(label: 'the projects', tone: :ruby, heading: :h2))

    expect(page).to have_css('h2.rc-track__label', text: 'the projects')
  end

  it 'renders a span by default, so it can sit above a real heading' do
    render_inline(described_class.new(label: 'for engineers', tone: :soft))

    expect(page).to have_css('span.rc-track__label')
  end

  it 'refuses an unknown tone' do
    expect { described_class.new(label: 'x', tone: :blue) }.to raise_error(ArgumentError, /tone must be/)
  end
end
