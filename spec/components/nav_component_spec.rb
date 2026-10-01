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

  it "carries the redesign's four sections" do
    render_in(:en)

    expect(page.all('.rc-nav__link').map { |link| link.text.split.first }).to eq(%w[journal work studio contact])
  end

  # Every section is a link now: /studio waited on real team data, and the roster arrived.
  it 'lets every section navigate' do
    render_in(:en)

    expect(page.all('.rc-nav__link').map(&:tag_name)).to all(eq('a'))
    expect(page).to have_css("a[href='/en/studio']")
  end

  # The roster is deliberately not a fifth item — it is reached from /studio, the footer, every
  # case page and ⌘K — so being on it keeps the studio lit rather than lighting nothing.
  it 'keeps the studio marked while the reader is in the roster' do
    render_in(:en, current: :studio)

    expect(page.find('.rc-nav__link.is-current').text).to eq('studio')
  end

  # One person's page on a site that is a studio's, and the thing a recruiter arrives for.
  it 'offers the CV as a chip beside the sections' do
    render_in(:en)

    expect(page).to have_css("a.rc-nav__cv[href='/en/cv']", text: 'CV')
    expect(page.all('.rc-nav__link').map(&:text)).not_to include('CV')
  end

  it 'translates the sections' do
    render_in(:uk)

    expect(page.all('.rc-nav__link').map { |link| link.text.split.first })
      .to eq(%w[журнал роботи студія контакти])
  end

  # The highlight is wayfinding; aria-current="page" is a claim about the address. On /team the
  # studio is lit, and telling a screen reader the reader is on the studio page would be a lie.
  it 'announces the current page only where the link is the page' do
    I18n.with_locale(:en) do
      with_request_url '/en/team' do
        render_inline(described_class.new(current: :studio))
      end
    end

    expect(page.find('.rc-nav__link.is-current').text).to eq('studio')
    expect(page).to have_no_css('.rc-nav__link[aria-current]')
  end

  it 'announces it on the page itself' do
    render_in(:en, current: :work)

    expect(page.find("a[aria-current='page']").text).to eq('work')
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

  describe 'the language switcher' do
    def switcher_hrefs(path)
      I18n.with_locale(:en) do
        with_request_url(path) { render_inline(described_class.new) }
      end

      page.all('.rc-nav__locale').pluck(:href)
    end

    it 'points each language at this same page' do
      expect(switcher_hrefs('/en/work/dna')).to eq(%w[/uk/work/dna /en/work/dna])
    end

    it 'carries the query string across' do
      expect(switcher_hrefs('/en/journal?tag_id=3&order=best'))
        .to eq(%w[/uk/journal?order=best&tag_id=3 /en/journal?order=best&tag_id=3])
    end

    # url_for reads host, action, controller and the like as routing instructions, and the
    # address bar is the reader's — or whoever sent them the link.
    %w[host=evil.example script_name=x anchor=y protocol=javascript controller=x action=x _recall=x].each do |query|
      it "keeps ?#{query} a value in the query, on this site" do
        hrefs = switcher_hrefs("/en/faq?#{query}")

        expect(hrefs).to eq(["/uk/faq?#{query}", "/en/faq?#{query}"])
      end
    end
  end
end
