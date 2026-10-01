# frozen_string_literal: true

require 'rails_helper'

describe 'the /management screens for a keyboard and a screen reader' do
  include_context 'when carrierwave cleanup'
  include_context 'when the cases are imported'

  before { sign_in create(:user, role: :admin) }

  def page = response.parsed_body

  describe 'the shell' do
    before { get '/en/management/posts' }

    it 'opens with a link past the sidebar to the content' do
      first_link = page.at_css('body a, body button')

      expect(first_link['class']).to eq('mg-skip')
      expect(first_link['href']).to eq('#main')
      expect(page.at_css('main#main.mg-content')['tabindex']).to eq('-1')
    end

    it 'puts the navigation in a labelled nav' do
      nav = page.at_css('nav#mg-sidebar-nav')

      expect(nav['aria-label']).to eq(I18n.t('management.sidebar_component.navigation', locale: :en))
      expect(nav.css('a.mg-model').size).to eq(4)
    end

    it 'marks only the screen being looked at as current' do
      current = page.css('a.mg-model[aria-current]')

      expect(current.size).to eq(1)
      expect(current.first['aria-current']).to eq('page')
      expect(current.first.at_css('.mg-model__name').text).to eq('Post')
    end

    it 'keeps the model name inside each link, so the collapsed rail still names it' do
      post_link = page.at_css('a.mg-model')

      expect(post_link.at_css('.mg-model__name').text).to eq('Post')
      expect(post_link.at_css('.mg-model__count')).to be_present
    end
  end

  describe 'the page heading' do
    {
      'the post list' => '/en/management/posts',
      'a new post' => '/en/management/posts/new',
      'the case list' => '/en/management/cases',
      'the case form' => '/en/management/cases/new',
      'the tag list' => '/en/management/tags',
      'the statistics' => '/en/management/statistics'
    }.each do |name, path|
      it "has the top bar's h1 on #{name}" do
        get path

        expect(page.css('.mg-topbar h1.mg-crumbs__here').size).to eq(1)
      end
    end

    it 'has no second h1 beside it on the list and form screens' do
      %w[posts cases cases/new tags statistics].each do |screen|
        get "/en/management/#{screen}"

        expect(page.css('h1').size).to eq(1)
      end
    end
  end

  describe 'the post list' do
    before do
      create(:post, title: 'Counting views properly')
      create(:post, :inactive)
    end

    it 'says which status filter is on' do
      get '/en/management/posts', params: { status: 'active' }

      current = page.css('a.mg-filter[aria-current]')

      expect(current.size).to eq(1)
      expect(current.first['aria-current']).to eq('true')
      expect(current.first.text).to include(I18n.t('management.posts.index.filters.active', locale: :en))
    end

    it 'says which filter is on when there is no status at all' do
      get '/en/management/posts'

      expect(page.at_css('a.mg-filter[aria-current]').text).to include('all')
    end

    it 'names the search field' do
      get '/en/management/posts'

      expect(page.at_css('input.mg-search__input')['aria-label'])
        .to eq(I18n.t('management.posts.index.search', locale: :en))
    end

    it 'names the post on its delete button and in the confirmation' do
      get '/en/management/posts'

      row = page.css('tbody tr').find { |tr| tr.text.include?('Counting views properly') }
      button = row.at_css('button.mg-action--danger')

      expect(button['aria-label']).to eq('Delete Counting views properly')
      expect(button.ancestors('form').first['data-confirm-message-value'])
        .to eq('Are you sure you want to delete Counting views properly?')
    end

    it 'gives every delete button a different name' do
      get '/en/management/posts'

      labels = page.css('button.mg-action--danger').pluck('aria-label')

      expect(labels.size).to eq(2)
      expect(labels.uniq.size).to eq(2)
    end

    it 'puts aria-sort on the column the list is ordered by, in the direction it runs' do
      get '/en/management/posts'
      expect(page.css('th[aria-sort]').pluck('aria-sort')).to eq(%w[descending])
      expect(page.at_css('th[aria-sort] .mg-table__sort').text).to include('↓')

      get '/en/management/posts', params: { sort: 'status', direction: 'asc' }
      expect(page.css('th[aria-sort]').pluck('aria-sort')).to eq(%w[ascending])
      expect(page.at_css('th[aria-sort] .mg-table__sort').text).to include('↑')
    end
  end

  describe 'the case list' do
    before { get '/en/management/cases' }

    it 'names the case on its edit and delete controls' do
      row = page.css('.case-row').find { |r| r.at_css('.case-row__title').text.include?('DNA') }

      expect(row.at_css('.delete button')['aria-label']).to eq('Delete DNA')
      expect(row.at_css('.edit a')['aria-label']).to eq('Edit DNA')
    end

    it 'names the case in the delete confirmation' do
      form = page.css('.case-row').find { |r| r.at_css('.case-row__title').text.include?('DNA') }.at_css('.delete form')

      expect(form['data-confirm-message-value']).to eq('Are you sure you want to delete DNA?')
    end

    it 'gives every delete control a different name' do
      labels = page.css('.case-row .delete button').pluck('aria-label')

      expect(labels.uniq.size).to eq(labels.size)
    end
  end

  describe 'the structure rows of the case form' do
    before { get '/en/management/cases/new' }

    it 'makes each row a group that is named' do
      rows = page.css('.mg-row[data-structure-rows-target="row"]')

      expect(rows).not_to be_empty
      expect(rows.pluck('role').uniq).to eq(%w[group])
      rows.each do |row|
        name = page.at_css("##{row['aria-labelledby']}")

        expect(name).to be_present
        expect(name.text).to eq(I18n.t('management.shared.structure_row.row', locale: :en))
      end
    end

    it 'carries the list name into the label of a row that is one string per language' do
      I18n.with_locale(:en) do
        %i[plain_body mine].each do |field|
          list = I18n.t(field, scope: 'management.cases.form')
          labels = page.css("label[for^='case_#{field}_0_']").map(&:text)

          expect(labels).to eq(I18n.available_locales.map { |locale| "#{list} · #{I18n.t(locale).downcase}" })
        end
      end
    end

    it 'gives every row, and the one the add button clones, its own name element' do
      ids = page.css('.mg-row__name').pluck('id')

      expect(ids.uniq.size).to eq(ids.size)
      expect(ids.grep(/__INDEX__/)).not_to be_empty
    end
  end

  describe 'the tag screens' do
    let!(:tag) { create(:tag, title: 'rails') }

    it 'names the tag on its edit and delete controls' do
      get '/en/management/tags'

      row = page.css('.tag').find { |t| t.text.include?('rails') }

      expect(row.at_css('.edit a')['aria-label']).to eq('Edit rails')
      expect(row.at_css('.delete button')['aria-label']).to eq('Delete rails')
    end

    it 'offers no search box that searches nothing' do
      get '/en/management/tags'

      expect(page.css('input[type="search"]')).to be_empty
    end

    describe 'the rename form' do
      before { get "/en/management/tags/#{tag.id}/edit" }

      it 'saves with a button that has a name' do
        save = page.at_css('.tag-editor .save-tag')

        expect(save.name).to eq('button')
        expect(save['type']).to eq('submit')
        expect(save['aria-label']).to eq('Save')
        expect(page.css('input[type="submit"][value=""]')).to be_empty
      end

      it 'cancels with a link that has a name and leaves the frame' do
        cancel = page.at_css('.tag-editor .cancel-tag-icon')

        expect(cancel.name).to eq('a')
        expect(cancel['href']).to eq('/en/management/tags')
        expect(cancel['aria-label']).to eq('Cancel')
        expect(cancel['data-turbo-frame']).to eq('_top')
      end

      it 'names the field' do
        expect(page.at_css('.tag-editor input[type="text"]')['aria-label'])
          .to eq(I18n.t('management.tags.form.title_label', locale: :en))
      end
    end
  end

  describe 'the post preview' do
    let(:post) { create(:post, description_en: '<p>one</p>', description_uk: '<p>тіло</p>') }

    it 'carries the language of its own tab, not the admin chrome' do
      get "/en/management/posts/#{post.slug}/preview", params: { preview_locale: 'uk' }

      expect(response.parsed_body.at_css('article.mg-preview__article')['lang']).to eq('uk')
    end
  end

  describe 'the editor language panes' do
    it 'declare their language, so the Ukrainian pane gets its own face and spellcheck' do
      post = create(:post)

      get "/en/management/posts/#{post.slug}/edit"

      panes = response.parsed_body.css('.mg-locale[data-locale]')
      expect(panes.to_h { |pane| [pane['data-locale'], pane['lang']] }).to eq('en' => 'en', 'uk' => 'uk')
    end
  end
end
