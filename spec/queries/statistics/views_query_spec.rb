# frozen_string_literal: true

require 'rails_helper'

describe Statistics::ViewsQuery, type: :query do
  let(:user) { create(:user) }
  let(:post) { create(:post) }
  let(:ahoy_visit) { create(:ahoy_visit, user:) }
  let(:now) { Time.zone.local(2023, 8, 15, 15, 5) }

  def view(time, name: 'Viewed Post')
    create(:ahoy_event, visit_id: ahoy_visit.id, name:, properties: { post_id: post.id }, time:)
  end

  before { travel_to(now) }

  it 'answers 0 with nothing recorded' do
    expect(described_class::PERIODS.keys.map { |period| described_class.call(period) } + [described_class.call])
      .to eq([0, 0, 0, 0])
  end

  context 'with views across the calendar' do
    before do
      view(now)
      view(Time.zone.local(2023, 8, 15, 23, 59))
      view(1.day.ago)
      view(1.month.ago)
      view(2.years.ago)
      view(3.years.from_now)
      view(now, name: 'Viewed Case')
    end

    it 'counts today' do
      expect(described_class.call(:day)).to eq(2)
    end

    it 'counts this month' do
      expect(described_class.call(:month)).to eq(3)
    end

    it 'counts this year' do
      expect(described_class.call(:year)).to eq(4)
    end

    it 'counts every post view ever, and nothing that is not one' do
      expect(described_class.call).to eq(6)
    end
  end

  it 'refuses a period it does not know' do
    expect { described_class.call(:week) }.to raise_error(KeyError)
  end
end
