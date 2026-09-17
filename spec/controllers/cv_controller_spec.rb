# frozen_string_literal: true

require 'rails_helper'

# /cv is a page again. It was a 301 to /work while /work carried the CV; /work stopped being
# one person's frame the moment six people appeared on it.
describe CVController do
  render_views

  include_context 'when the cases are imported'
  include_context 'when the cv is imported'

  let(:action) { :show }
  let(:params) { { locale: 'en' } }

  it_behaves_like 'has http success'

  it 'renders the CV, not a redirect' do
    get(action, params:)

    expect(response.body).to include('Danyil Shkoropad', 'Curriculum vitae', 'pgvector')
  end

  it 'lists the projects with their marks — the one place the mark belongs' do
    get(action, params:)

    expect(response.body.scan('class="cv-row hover-row"').size).to eq(Case.count)
    expect(response.body).to include('>01<')
  end

  # What stops the CV and the project list from being the same page twice: the career states
  # the job, the chips point at the evidence.
  it 'points each career entry at the cases behind it' do
    get(action, params:)

    expect(response.body).to include(work_case_path(slug: 'intelligence', locale: 'en'))
    expect(response.body).to include('rc-chip--link')
  end

  it 'offers the print action, because this is the page a recruiter prints' do
    get(action, params:)

    expect(response.body).to include('cv-page__print')
    expect(response.body).to include('data-controller="print"')
  end

  it 'renders the Ukrainian copy under the uk locale' do
    get(action, params: { locale: 'uk' })

    expect(response.body).to include('Резюме', 'Даниїл Шкоропад')
  end

  it 'declares itself a person to a search engine' do
    get(action, params:)

    expect(response.body).to include('"@type":"ProfilePage"')
  end

  # A database that has never run `rake cv:import` has no CV. The page says so rather than
  # printing a heading over nothing — the same designed state a person page has.
  describe 'on a database with no CV imported' do
    before { CVProfile.delete_all }

    it 'says the CV is not filled in, and shows no empty career' do
      get(action, params:)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('pf-pending')
      expect(response.body).not_to include('pf-career')
      expect(response.body).not_to include('pf-contact')
    end

    # The projects are the portfolio's rather than the CV's, so they are there either way.
    it 'still lists the projects' do
      get(action, params:)

      expect(response.body.scan('class="cv-row hover-row"').size).to eq(Case.count)
    end
  end
end
