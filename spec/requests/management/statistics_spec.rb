# frozen_string_literal: true

require 'rails_helper'

describe 'the admin statistics screen', type: :request do
  include_context 'when the cases are imported'

  context 'when an admin is signed in' do
    let(:kase) { Case.find_by!(slug: 'dna') }
    let(:post_record) { I18n.with_locale(:en) { create(:post, title: 'A counted entry') } }

    before do
      sign_in create(:user, :admin)

      { day: 42, month: 100, year: 1000 }.each do |period, views|
        allow(Statistics::ViewsQuery).to receive(:call).with(period).and_return(views)
      end
      allow(Statistics::ViewsQuery).to receive(:call).with(no_args).and_return(10_000)
      allow(Statistics::PostViewsQuery).to receive(:call).and_return([[post_record, 60]])
      allow(Statistics::CaseViewsQuery).to receive(:call).and_return([[kase, 7]])

      get management_statistics_path(locale: 'en')
    end

    def page = response.parsed_body

    it 'prints the four periods' do
      expected = { today: '42', month: '100', year: '1,000', all: '10,000' }
                 .transform_keys { I18n.t("management.statistics.index.periods.#{it}", locale: :en) }
      printed = page.css('.mg-stat').to_h { [it.at_css('.mg-stat__label').text, it.at_css('.mg-stat__value').text] }

      expect(response).to have_http_status(:ok)
      expect(printed).to eq(expected)
    end

    # The per-case counts are the question the screen exists to answer.
    it 'lists the views of each case' do
      expect(response.body).to include("/work/#{kase.slug}")
      expect(page.css('.mg-cell--mono').map(&:text)).to include('7')
    end

    it 'lists the views of each post' do
      expect(response.body).to include('A counted entry', "/post/#{post_record.slug}")
      expect(page.css('.mg-cell--mono').map(&:text)).to include('60')
    end
  end

  context 'when a reader without staff rights is signed in' do
    before do
      sign_in create(:user)

      get management_statistics_path(locale: 'uk')
    end

    it 'sends them to the front page and says why' do
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to be_present
    end
  end
end
