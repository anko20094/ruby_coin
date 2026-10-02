# frozen_string_literal: true

require 'rails_helper'

describe 'Profile small blocks', type: :component do # rubocop:disable RSpec/DescribeClass
  around { |example| I18n.with_locale(:en) { example.run } }

  describe Profile::DidComponent do
    it 'lists one line per item, through the sanitiser' do
      render_inline(described_class.new(lines: ['Built <b>the</b> importer', 'Kept it']))

      expect(page.all('ul.pf-did > li.pf-did__item').size).to eq(2)
      expect(page).to have_css('li b', text: 'the')
    end

    it 'has a dense variant for cards' do
      render_inline(described_class.new(lines: ['x'], dense: true))

      expect(page).to have_css('ul.pf-did.pf-did--dense')
    end
  end

  describe Profile::PendingComponent do
    it 'says the CV is not written yet, in the default words or the ones it is given' do
      render_inline(described_class.new)
      expect(page).to have_css('.pf-pending h2', text: I18n.t('profile.pending.title'))
      expect(page).to have_css('p.pf-pending__body', text: I18n.t('profile.pending.body'))

      render_inline(described_class.new(body: I18n.t('cv.show.pending_body')))
      expect(page).to have_css('p.pf-pending__body', text: I18n.t('cv.show.pending_body'))
    end
  end
end
