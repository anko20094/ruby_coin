# frozen_string_literal: true

require 'rails_helper'

# Turbo Drive is off by decision, so every click is a full page load and the browser cache is
# the only thing between a reader on 3G and paying for the whole document again. Nothing was
# using it: Rails' default ETag digests the body, and the body carried a fresh CSRF token on
# every response, so no two responses ever matched.
describe 'HTTP caching', type: :request do
  include_context 'when the cases are imported'
  include_context 'when the cv is imported'

  pages = %w[/en/work /en/work/dna /en/cv /en/contact /en/faq /en/studio /en/team /en/team/danyil]

  # The test environment turns forgery protection off, so csrf_meta_tags would render nothing
  # in every layout and the examples that name the token could not fail.
  around do |example|
    was = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    example.run
  ensure
    ActionController::Base.allow_forgery_protection = was
  end

  def etag_for(path)
    get path
    response.headers['ETag']
  end

  def revalidate(path, etag)
    get path, headers: { 'If-None-Match' => etag }
  end

  def rename_case_after(slug)
    neighbour = Case.find_by!(slug: slug).neighbours.last
    neighbour.update!(title: { 'en' => 'Renamed', 'uk' => 'Перейменовано' })
  end

  pages.each do |path|
    it "answers an unchanged #{path} with 304 and no body" do
      revalidate(path, etag_for(path))

      expect(response).to have_http_status(:not_modified)
      expect(response.body).to be_empty
    end

    it "lets the browser keep #{path} for five minutes, and no shared cache" do
      get path

      expect(response.headers['Cache-Control']).to include("max-age=#{HttpCaching::PAGE_TTL.to_i}", 'private')
      expect(response.headers['Cache-Control']).not_to include('public')
    end

    it "expires #{path} when the day turns, because the footer and the draft chip read the clock" do
      before_midnight = etag_for(path)

      travel_to(1.day.from_now) { revalidate(path, before_midnight) }

      expect(response).to have_http_status(:success)
    end

    it "expires #{path} when a deploy changes what pages are rendered from" do
      before_deploy = etag_for(path)
      allow(HttpCaching).to receive(:release).and_return('the next deploy')

      revalidate(path, before_deploy)

      expect(response).to have_http_status(:success)
    end

    it "expires #{path} when the CV changes, which the footer prints on every page" do
      before_import = etag_for(path)
      CVProfile.current.update!(location: { 'en' => 'Elsewhere', 'uk' => 'Деінде' })

      revalidate(path, before_import)

      expect(response).to have_http_status(:success)
    end
  end

  # The pages that print the roster: the people, their photographs and what they did.
  %w[/en/work /en/work/dna /en/cv /en/studio /en/team /en/team/danyil].each do |path|
    it "expires #{path} when the roster files or a photograph change" do
      before_edit = etag_for(path)
      allow(Team).to receive(:version).and_return('another face')

      revalidate(path, before_edit)

      expect(response).to have_http_status(:success)
    end
  end

  # The page prints its neighbours' titles and how many cases there are, so a change to any
  # other case has to reach it; the pages that list or credit cases follow the same rule.
  %w[/en/work /en/work/dna /en/cv /en/team/danyil].each do |path|
    it "expires #{path} when another case is renamed" do
      before_rename = etag_for(path)
      rename_case_after('dna')

      revalidate(path, before_rename)

      expect(response).to have_http_status(:success)
    end
  end

  it 'expires a case page when a case is added or removed, because it prints how many there are' do
    before_removal = etag_for('/en/work/dna')
    Case.where(slug: 'rubycoin').delete_all

    revalidate('/en/work/dna', before_removal)

    expect(response).to have_http_status(:success)
  end

  it 'stops being fresh when the content changes' do
    before_edit = etag_for('/en/work/dna')

    Case.find_by!(slug: 'dna').update!(year: { 'en' => '2099', 'uk' => '2099' })

    revalidate('/en/work/dna', before_edit)

    expect(response).to have_http_status(:success)
  end

  it 'gives the two locales different entity tags for the same case' do
    expect(etag_for('/en/work/dna')).not_to eq(etag_for('/uk/work/dna'))
  end

  describe 'a page carrying a message' do
    let!(:before_message) { etag_for('/en/work') }
    let(:message) { I18n.t('application_controller.alert', locale: :uk) }

    before do
      sign_in create(:user)
      get '/uk/management/posts'
    end

    it 'is not answered with a copy of the page from before it' do
      revalidate('/en/work', before_message)

      expect(response).to have_http_status(:success)
      expect(response.body).to include(message)
    end

    it 'is not held by the browser either' do
      get '/en/work'

      expect(response.headers['Cache-Control']).not_to include('max-age=300')
    end
  end

  # Removing csrf_meta_tags from the theme layout is what makes the rest of the site
  # conditionally cacheable too, so this pins the reason it is gone.
  it 'keeps the theme layout free of the per-response CSRF token' do
    get '/en/journal'

    expect(response.body).not_to include('name="csrf-token"')
  end

  it 'still gives the admin its CSRF token' do
    sign_in create(:user, role: :admin)

    get '/en/management/posts'

    expect(response.body).to include('name="csrf-token"')
  end

  describe 'what a release is made of' do
    let(:sources) { Rails.root.glob(HttpCaching::RELEASE_SOURCES).map { |path| path.relative_path_from(Rails.root).to_s } }

    it 'covers the layout, the components, the helpers, the copy and the stylesheet' do
      %w[
        app/views/layouts/theme.html.slim app/components/nav_component.html.slim app/helpers/meta_helper.rb
        config/locales/en.yml app/assets/stylesheets/theme.scss
      ].each do |file|
        expect(sources).to include(file), "#{file} would not expire a cached page"
      end
    end
  end
end
