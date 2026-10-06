# frozen_string_literal: true

require 'rails_helper'

describe CaseTeamComponent, type: :component do
  around { |example| I18n.with_locale(:en) { example.run } }

  def render_for(slug)
    with_request_url("/en/work/#{slug}") do
      render_inline(described_class.new(team: Team.for_case(slug), slug:))
    end
  end

  it 'draws a card per contributor, each leading to their page with the project in tow' do
    render_for('dna')

    cards = page.all('.wk-teammate')
    expect(cards.size).to eq(Team.for_case('dna').size)
    expect(page).to have_css("a[href='/en/team/danyil?from=dna']")
    expect(page).to have_css('h2', text: /#{I18n.t('work.case.team')} · /)
  end

  it 'states solo work instead of drawing a team of one' do
    render_for('intelligence')

    expect(page).to have_css('.wk-solo .wk-solo__title', text: I18n.t('work.case.team_solo'))
    expect(page).to have_no_css('.wk-teammate')
  end
end
