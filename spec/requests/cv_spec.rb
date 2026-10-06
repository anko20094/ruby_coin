# frozen_string_literal: true

require 'rails_helper'

describe 'the CV page', type: :request do
  include_context 'when the cases are imported'

  it 'renders the CV, not a redirect' do
    get cv_path(locale: 'en')

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Danyil Shkoropad', 'Curriculum vitae', 'pgvector')
  end

  it 'lists the projects with their marks — the one place the mark belongs' do
    get cv_path(locale: 'en')

    expect(response.body.scan('class="cv-row hover-row"').size).to eq(Case.count)
    expect(response.body).to include('>01<')
  end

  # The career states the job, the chips point at the evidence.
  it 'points each career entry at the cases behind it' do
    get cv_path(locale: 'en')

    expect(response.body).to include(work_case_path(slug: 'intelligence', locale: 'en'))
    expect(response.body).to include('rc-chip--link')
  end

  it 'offers the print action, because this is the page a recruiter prints' do
    get cv_path(locale: 'en')

    expect(response.body).to include('cv-page__print')
    expect(response.body).to include('data-controller="print"')
  end

  it 'renders the Ukrainian copy under the uk locale' do
    get cv_path(locale: 'uk')

    expect(response.body).to include('Резюме', 'Даниїл Шкоропад')
  end
end
