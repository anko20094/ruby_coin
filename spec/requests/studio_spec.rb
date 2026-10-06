# frozen_string_literal: true

require 'rails_helper'

describe 'the studio page', type: :request do
  it 'shows the whole roster, each card linking at that person' do
    get studio_path(locale: 'en')

    expect(response).to have_http_status(:ok)
    expect(response.body.scan('class="st-card"').size).to eq(Team.crew.size)
    expect(response.body).to include(person_path('mykhailo', locale: 'en'))
  end

  it 'translates its own copy, not only the roster' do
    get studio_path(locale: 'uk')

    expect(response.body).to include('Студія', 'Rails-студія')
    expect(response.body).not_to include('The studio')
  end

  describe 'the alumni' do
    let(:alumni_block) { response.body[%r{<section class="st-alumni".*?</section>}m] }

    it 'names every one of them' do
      get studio_path(locale: 'en')

      # #name reads I18n.locale at call time, so the names are built inside the block.
      names = I18n.with_locale(:en) { Team.alumni.map(&:name) }

      names.each { |name| expect(alumni_block).to include(name) }
      expect(alumni_block.scan('st-alumni__pill').size).to eq(Team.alumni.size)
    end

    context 'when an alumnus is credited on a project' do
      # No alumnus in the shipped roster is credited on a project, so vladyslav stands in as one.
      let(:credited_alumnus) do
        Person.new('id' => 'vladyslav', 'status' => 'alumni', 'name' => { 'en' => 'Vladyslav', 'uk' => 'Владислав' })
      end

      before do
        allow(Team).to(receive(:roster).and_wrap_original do |original|
          original.call.merge('vladyslav' => credited_alumnus)
        end)
      end

      # A bare name gets no link (its page would be invented); a name credited on a case does.
      it 'links the ones with something behind the name, and only those' do
        get studio_path(locale: 'en')

        linked = Team.alumni.select(&:page?)

        expect(linked).to be_present, 'no alumnus is credited, so this rule proves nothing'
        expect(alumni_block.scan('<a ').size).to eq(linked.size)
        linked.each { |person| expect(alumni_block).to include(person_path(person, locale: 'en')) }
      end
    end

    it 'translates their names rather than leaving the roster half in Latin' do
      get studio_path(locale: 'uk')

      expect(response.body).to include('Андрій Мазурок')
      expect(response.body).not_to include('Andrii Mazurok')
    end
  end
end
