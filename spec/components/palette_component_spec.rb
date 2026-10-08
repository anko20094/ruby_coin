# frozen_string_literal: true

require 'rails_helper'

describe PaletteComponent, type: :component do
  around { |example| I18n.with_locale(:en) { example.run } }

  before { with_request_url('/en') { render_inline(described_class.new) } }

  it 'searches the locale the page is in' do
    palette = page.find('.rc-palette')

    expect(palette['data-palette-url-value']).to eq('/en/search.json')
    expect(palette['data-palette-all-url-value']).to eq('/en/search')
  end

  it 'also opens when a list asks for it with / and has no search field of its own' do
    expect(page).to have_css('.rc-palette[data-action~="rubycoin:palette@window->palette#open"]')
  end

  it 'opens from a named button and is a labelled dialog' do
    button = page.find('button.rc-palette__open')

    expect(button).to have_css('span.rc-palette__label', text: I18n.t('global.palette.open'))
    expect(button).to have_css('svg.rc-palette__icon[aria-hidden="true"]')
    expect(button).to have_no_css('kbd')
    expect(page).to have_css('dialog.rc-palette__dialog[aria-label]', visible: :all)
  end

  it 'wires the input to the results as a combobox' do
    input = page.find('input.rc-palette__input', visible: :all)

    expect(input['role']).to eq('combobox')
    expect(input['aria-controls']).to eq('rc-palette-results')
  end
end
