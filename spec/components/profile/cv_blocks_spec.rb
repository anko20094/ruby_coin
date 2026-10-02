# frozen_string_literal: true

require 'rails_helper'

# The CV blocks /cv and /team/:person share, rendered from the real config/portfolio/cv.yml.
describe 'Profile CV blocks', type: :component do # rubocop:disable RSpec/DescribeClass
  include_context 'when the cases are imported'

  around { |example| I18n.with_locale(:en) { example.run } }

  let(:cv) { Team.owner_cv }

  describe Profile::SummaryComponent do
    it 'prints the summary as markup under its track tag' do
      render_inline(described_class.new(profile: cv))

      expect(page).to have_css('section.pf-block--summary h2', text: I18n.t('profile.summary'))
      expect(page).to have_css('p.pf-summary')
    end
  end

  describe Profile::CareerComponent do
    it 'gives every entry a heading' do
      render_inline(described_class.new(profile: cv))

      expect(page.all('.pf-career__entry h3.pf-career__org').size).to eq(cv.experience.size)
    end

    it 'links the cases an entry names only when it is handed them' do
      render_inline(described_class.new(profile: cv))
      expect(page).to have_no_css('.pf-career__cases')

      render_inline(described_class.new(profile: cv, cases_by_slug: Case.ordered.index_by(&:slug)))
      expect(page).to have_css(".pf-career__cases a[href^='/en/work/']")
    end
  end

  describe Profile::StackComponent do
    it 'groups the stack into chips' do
      render_inline(described_class.new(profile: cv))

      expect(page.all('.pf-stack__group').size).to eq(cv.stack_groups.size)
      expect(page).to have_css('.pf-stack__group .rc-chips .rc-chip')
    end
  end

  describe Profile::ContactPanelComponent do
    it 'draws the contacts and the facts beside them' do
      render_inline(described_class.new(profile: cv))

      expect(page).to have_css('.pf-contact .pf-contact__label.is-ruby', text: I18n.t('profile.contact'))
      expect(page.all('a.pf-contact__value[rel="noreferrer"]').size).to eq(cv.contact_rows.size)
    end

    it 'draws no frame around nothing' do
      render_inline(described_class.new(profile: Person::CV.new({})))

      expect(rendered_content).to be_blank
    end
  end
end
