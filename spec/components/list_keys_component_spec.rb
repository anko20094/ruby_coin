# frozen_string_literal: true

require 'rails_helper'

describe ListKeysComponent, type: :component do
  it 'draws the J/K and / hint hidden, for list-nav to show' do
    render_inline(described_class.new)

    hint = page.find('p.rc-keys[data-list-nav-target="hint"]', visible: :hidden)
    expect(hint.all('kbd', visible: :hidden).map { |key| key.text(:all) }).to eq(%w[J K /])
  end

  it 'says what the keys do in the reader’s language' do
    I18n.with_locale(:uk) { render_inline(described_class.new) }

    hint = page.find('p.rc-keys', visible: :hidden)
    expect(hint.text(:all)).to include(I18n.t('global.list_keys.navigate', locale: :uk))
  end
end
