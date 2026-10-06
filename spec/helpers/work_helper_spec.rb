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
end
