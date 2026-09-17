# frozen_string_literal: true

require 'rails_helper'

describe FooterComponent, type: :component do
  include_context 'when the cv is imported'

  # The roster is not in the main nav, so the footer is one of the two ways to it.
  it 'lists the crew and the CV among the places to go' do
    I18n.with_locale(:en) do
      with_request_url '/en/work' do
        render_inline(described_class.new)
      end
    end

    expect(page.all('.rc-footer__sections a').map(&:text)).to eq(
      ['journal', 'rss', 'all cases', 'the crew', 'cv', 'faq', 'say hi']
    )
    expect(page).to have_css("a[href='/en/team']")
    expect(page).to have_css("a[href='/en/cv']")
    # A page nobody links to is a page nobody finds.
    expect(page).to have_css("a[href='/en/faq']")
  end

  it 'shows github, telegram and email in the design order' do
    with_request_url '/en/work' do
      render_inline(described_class.new)
    end

    expect(page.all('.rc-footer__contacts a').map(&:text))
      .to eq(['github.com/anko20094', '@anko20094', 'anko20094@gmail.com'])
  end

  # The name is localised now, so the copyright line reads in whichever language the page is.
  it 'carries the real identity, never the prototype placeholders' do
    I18n.with_locale(:en) do
      with_request_url '/en/work' do
        render_inline(described_class.new)
      end
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
    expect(page).to have_text('Даниїл Шкоропад')
  end
end
