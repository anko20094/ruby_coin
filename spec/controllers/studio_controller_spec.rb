# frozen_string_literal: true

require 'rails_helper'

describe StudioController do
  render_views

  let(:action) { :show }
  let(:params) { { locale: 'en' } }

  it_behaves_like 'has http success'

  it 'shows the whole roster, each card linking at that person' do
    get(action, params:)

    expect(response.body.scan('class="st-card"').size).to eq(Team.people.size)
    expect(response.body).to include(person_path('mykhailo', locale: 'en'))
  end

  # This page sat English-only above correctly translated crew cards for a while, which reads
  # worse than no translation at all.
  it 'translates its own copy, not only the roster' do
    get(action, params: { locale: 'uk' })

    expect(response.body).to include('Студія', 'Rails-студія')
    expect(response.body).not_to include('The studio')
  end

  it 'ships no alumni chips, because those names are still placeholders' do
    get(action, params:)

    expect(response.body).not_to include('alumni')
  end
end
