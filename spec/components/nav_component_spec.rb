# frozen_string_literal: true

require 'rails_helper'

describe NavComponent, type: :component do
  # The app's default locale is uk, so English expectations have to say so.
  def render_in(locale, current: :work)
    I18n.with_locale(locale) do
      with_request_url "/#{locale}/work" do
        render_inline(described_class.new(current: current))
      end
    end
  end

  it "carries the redesign's four sections and no cv" do
    render_in(:en)

    expect(page.all('.rc-nav__link').map { |link| link.text.split.first }).to eq(%w[journal work studio contact])
  end

  it 'translates the sections' do
    render_in(:uk)

    expect(page.all('.rc-nav__link').map { |link| link.text.split.first })
      .to eq(%w[журнал роботи студія контакти])
  end

  # /studio has nowhere to go until there is team data. It used to redirect to /work, which
  # meant two items in this nav led to the same page and the wrong one lit up.
  it 'keeps an unbuilt section in its place without letting it navigate' do
    render_in(:en)

    studio = page.all('.rc-nav__link')[2]

    expect(studio.tag_name).to eq('span')
    expect(studio[:class]).to include('is-soon')
    expect(studio).to have_css('.rc-nav__soon')
    expect(page).to have_no_css("a[href='/en/studio']")
  end

  it 'marks the current section' do
    render_in(:en, current: :journal)

    expect(page.find('.rc-nav__link.is-current').text).to eq('journal')
  end

  it 'marks nothing when the section is unknown' do
    render_in(:en, current: nil)

    expect(page).to have_no_css('.rc-nav__link.is-current')
  end

  it 'offers both locales, with the active one marked' do
    render_in(:en)

    expect(page.all('.rc-nav__locale').map(&:text)).to eq(%w[UK EN])
    expect(page.find('.rc-nav__locale.is-current').text).to eq('EN')
  end
end
