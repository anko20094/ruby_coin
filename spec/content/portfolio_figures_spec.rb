# frozen_string_literal: true

require 'rails_helper'

# Every figure in config/portfolio is a claim about a real system and was measured against it
# once. They are prose in a YAML file, so nothing but a reader notices
# when one page says two things — or when a claim that was corrected comes back in a sentence
# nobody remembered to look at.
RSpec.describe 'the portfolio figures' do
  def portfolio(name) = YAML.load_file(Rails.root.join('config', 'portfolio', "#{name}.yml"))

  def strings(node)
    case node
    when Hash then node.values.flat_map { |value| strings(value) }
    when Array then node.flat_map { |value| strings(value) }
    when String then [node]
    else []
    end
  end

  let(:cases) { portfolio('cases').fetch('cases').index_by { |kase| kase['slug'] } }
  let(:team) { portfolio('team').fetch('contributions') }

  it 'gives the RubyCoin visits tile the window the paragraph beside it states' do
    rubycoin = cases.fetch('rubycoin')
    label = rubycoin['metrics'].second['label']
    paragraph = rubycoin['plain']['body'].second

    { 'en' => / from (.+?) 2026/, 'uk' => / із (.+?) 2026/ }.each do |locale, window|
      expect(label[locale][window, 1]).to eq(paragraph[locale][window, 1]), locale
    end
  end

  it 'counts ChatGPT Bot payments as orders, because an autopay renewal is an order and not a person' do
    prose = strings(cases.fetch('chatgpt')['plain'])

    expect(prose.grep(/of them paid|із них заплатили/)).to be_empty
  end

  it 'does not use the 222k user counter as referral volume' do
    expect(strings(cases.fetch('chatgpt').except('metrics')).grep(/222[, ]?000/)).to be_empty
  end

  it 'gives WardyBot one team size, the ten that team.yml carries' do
    claims = strings(cases.fetch('wardybot')) + strings(team.fetch('wardybot'))

    expect(claims.grep(/\b14\b|fourteen|чотирнадцят/)).to be_empty
  end

  it 'gives the Leads permission matrix one size wherever it is printed' do
    sizes = (strings(cases.fetch('leads')) + strings(team.fetch('leads')))
            .flat_map { |text| text.scan(/(\d+)(?:-roles| ролей)?\s*[×x]\s*(\d+)/) }

    expect(sizes.uniq).to eq([%w[9 12]])
  end

  it 'counts only the months Intelligence has a mainline commit in' do
    months = cases.fetch('intelligence')['metrics'].second['label']

    expect(months.values).to all(include('33'))
  end

  it 'counts RubyCoin commits on master, not on every ref ever fetched' do
    expect(strings(cases.fetch('rubycoin')).grep(/440\+/)).to be_empty
  end

  it 'prints no row count the owner cannot produce for the CV' do
    expect(strings(portfolio('cv')).grep(/100M-row|100 млн/)).to be_empty
  end
end
