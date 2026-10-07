# frozen_string_literal: true

require 'rails_helper'

# A case's title, tagline and headline figure are printed inside a card that is itself a link
# (a button, on the case page), and the case editor offers a link for every one of them. A link
# in a link ends the outer one early, so the rest of the card stops being clickable.
describe 'a link written into a case field', type: :request do
  include_context 'when the cases are imported'

  let(:link) { '<a href="https://example.com/inside-a-card">linked</a>' }

  before do
    dna = Case.find_by!(slug: 'dna')
    metrics = dna[:metrics].map(&:deep_dup)
    metrics.first['value']['en'] = "33M #{link}"
    metrics.first['label']['en'] = "reach #{link}"

    dna.update_columns(title: dna[:title].merge('en' => "DNA #{link}"),
                       tagline: dna[:tagline].merge('en' => "tagline #{link}"), metrics:)
  end

  it 'is left out of the cards on /work' do
    get work_path(locale: 'en')

    expect(response.body).not_to include('inside-a-card')
    expect(response.body).to include('tagline linked').and include('reach linked')
  end

  it 'is left out of the cards on the home page' do
    get root_path(locale: 'en')

    expect(response.body).not_to include('inside-a-card')
    expect(response.body).to include('tagline linked')
  end

  it 'is left out of the project rows on /cv' do
    get cv_path(locale: 'en')

    expect(response.body).not_to include('inside-a-card')
    expect(response.body).to include('tagline linked').and include('reach linked')
  end

  it 'is left out of the metric buttons on the case page' do
    get work_case_path(locale: 'en', slug: 'dna')

    metrics = response.parsed_body.css('button.wk-metric')

    expect(metrics.css('a')).to be_empty
    expect(metrics.map(&:text).join).to include('reach linked')
  end
end
