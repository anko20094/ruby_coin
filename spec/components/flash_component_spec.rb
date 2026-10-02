# frozen_string_literal: true

require 'rails_helper'

describe FlashComponent, type: :component do
  around { |example| I18n.with_locale(:en) { example.run } }

  it 'announces every message from one polite live region' do
    render_inline(described_class.new(flash: { notice: 'Saved' }))

    region = page.find('.rc-flash')
    expect(region['aria-live']).to eq('polite')
    expect(region['aria-atomic']).to eq('true')
    expect(page).to have_css('.rc-flash__item--notice[role="status"] .rc-flash__text', text: 'Saved')
  end

  it 'gives the alert tone to every key Rails, Devise and Pundit use for a failure' do
    render_inline(described_class.new(flash: { alert: 'a', error: 'b', danger: 'c', success: 'd' }))

    expect(page.all('.rc-flash__item--alert[role="alert"]').size).to eq(3)
    expect(page.all('.rc-flash__item--notice[role="status"]').size).to eq(1)
  end

  it 'can be closed by hand' do
    render_inline(described_class.new(flash: { notice: 'Saved' }))

    close = page.find('button.rc-flash__close')
    expect(close['data-action']).to eq('dismiss#close')
    expect(close['aria-label']).to eq(I18n.t('global.dismiss'))
  end

  it 'leaves on its own, later for an alert, and holds while hovered or focused' do
    render_inline(described_class.new(flash: { notice: 'Saved', alert: 'Wrong password' }))

    notice = page.find('.rc-flash__item--notice')
    alert = page.find('.rc-flash__item--alert')
    expect(notice['data-controller']).to eq('dismiss')
    expect(notice['data-dismiss-after-value'].to_i).to be < alert['data-dismiss-after-value'].to_i
    expect(notice['data-action']).to include('mouseenter->dismiss#pause', 'focusin->dismiss#pause',
                                             'mouseleave->dismiss#resume', 'focusout->dismiss#resume')
  end

  it 'skips blank messages and the flags Devise keeps in the flash' do
    render_inline(described_class.new(flash: { notice: '', timedout: true, alert: 'Signed out' }))

    expect(page.all('.rc-flash__text').map(&:text)).to eq(['Signed out'])
  end

  it 'renders an empty region, so a later message has somewhere to be announced' do
    render_inline(described_class.new(flash: {}))

    expect(page).to have_css('.rc-flash', visible: :all)
    expect(page).to have_no_css('.rc-flash__item')
  end

  it 'wraps itself in the Turbo frame a stream replaces, when asked to' do
    render_inline(described_class.new(flash: { notice: 'Saved' }, frame_id: 'flash_message'))

    expect(page).to have_css('turbo-frame#flash_message .rc-flash .rc-flash__item')
  end
end
