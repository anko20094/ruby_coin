# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WorkHelper do
  around { |example| I18n.with_locale(:en) { example.run } }

  describe '#case_sections' do
    it 'names every section the case page draws, in order' do
      expect(helper.case_sections(team: true).map(&:first)).to eq(%w[plain engineers team contact])
    end

    it 'leaves the team out when the page has none' do
      expect(helper.case_sections(team: false).map(&:first)).to eq(%w[plain engineers contact])
    end
  end

  describe '#figure' do
    it 'sets a unit a size down after its number' do
      expect(helper.figure('33 млн+')).to eq('33<small class="rc-figure__unit"> млн+</small>')
    end

    it 'keeps a unit with a full stop in it' do
      expect(helper.figure('10 тис.+')).to include('<small class="rc-figure__unit"> тис.+</small>')
    end

    it 'leaves a figure without a word unit whole' do
      expect(helper.figure('×20')).to eq('×20')
      expect(helper.figure('20,5 %')).to eq('20,5 %')
      expect(helper.figure('#2 / 14')).to eq('#2 / 14')
    end

    it 'turns entities back into characters, a no-break space included' do
      expect(helper.figure('90&nbsp;%')).to eq("90\u00a0%")
      expect(helper.figure('2,1&nbsp;млн')).to eq("2,1<small class=\"rc-figure__unit\">\u00a0млн</small>")
    end

    it 'escapes what it prints' do
      expect(helper.figure('<b>5</b> ГБ')).to eq('5<small class="rc-figure__unit"> ГБ</small>')
    end
  end
end
