# frozen_string_literal: true

require 'rails_helper'

describe FooterComponent, type: :component do
  # The roster is not in the main nav, so the footer is one of the two ways to it.
  it 'lists the crew and the CV among the places to go' do
    I18n.with_locale(:en) do
      with_request_url '/en/work' do
        render_inline(described_class.new)
      end
    end

    expect(page.all('.rc-footer__sections a').map(&:text)).to eq(
      ['Journal', 'RSS', 'All projects', 'The team', 'CV', 'FAQ', 'Contact']
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

  it 'closes on the call, with the owner’s address as its button' do
    I18n.with_locale(:en) do
      with_request_url('/en/work') { render_inline(described_class.new) }
    end

    expect(page).to have_css('footer.rc-footer.rc-scene .rc-footer__title', text: 'Let’s work together.')
    expect(page).to have_css("a.rc-footer__mail[href='mailto:anko20094@gmail.com']", text: 'anko20094@gmail.com')
  end

  # /contact is the call already.
  it 'leaves the call out when asked to be quiet' do
    I18n.with_locale(:en) do
      with_request_url('/en/contact') { render_inline(described_class.new(cta: false)) }
    end

    expect(page).to have_css('footer.rc-footer--quiet')
    expect(page).to have_no_css('.rc-footer__cta')
    expect(page).to have_css('.rc-footer__sections a', text: 'Journal')
  end
end
