# frozen_string_literal: true

require 'rails_helper'

describe FooterComponent, type: :component do
  it 'shows github, telegram and email in the design order' do
    with_request_url '/en/work' do
      render_inline(described_class.new)
    end

    expect(page.all('.rc-footer__contacts a').map(&:text))
      .to eq(['github.com/anko20094', '@anko20094', 'anko20094@gmail.com'])
  end

  it 'carries the real identity, never the prototype placeholders' do
    with_request_url '/en/work' do
      render_inline(described_class.new)
    end

    expect(page).to have_text('Danyil Shkoropad')
    expect(page).to have_no_text('RubyCoin LLC')
    expect(page).to have_no_text('ronico-ua')
  end

  it 'localises the location line' do
    I18n.with_locale(:uk) do
      with_request_url '/uk/work' do
        render_inline(described_class.new)
      end
    end

    expect(page).to have_text('Україна · віддалено')
  end
end
