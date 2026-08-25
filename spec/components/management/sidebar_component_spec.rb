# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Management::SidebarComponent, type: :component do
  include_context 'when the cases are imported'

  # The hints are translated, so read them in one language.
  around { |example| I18n.with_locale(:en) { example.run } }

  # User#set_nickname overwrites whatever is passed in, deriving it from the email, so the
  # spec asserts against what the record actually ended up with.
  let(:user) { create(:user, role: :admin) }

  before { create_list(:post, 2) }

  it 'lists the models this admin has, with real counts' do
    render_inline(described_class.new(user: user, current: :posts))

    names = page.all('.mg-model__name').map(&:text)
    # No CV: it has no screen. It is config/portfolio/cv.yml, imported by `rake cv:import`.
    expect(names).to eq(%w[Post Case Tag Statistics])
    expect(page).to have_css('.mg-model__count', text: Post.count.to_s)
    expect(page).to have_css('.mg-model__count', text: Case.count.to_s)
  end

  # The design drew a ⌘K palette and Settings / Users / Audit / Redirect entries. None of them
  # exist here, and a sidebar advertising screens that are not there is worse than a short one.
  it 'advertises nothing that does not exist' do
    render_inline(described_class.new(user: user, current: :posts))

    expect(page).to have_no_text('Redirect')
    expect(page).to have_no_text('Audit')
    expect(page).to have_no_text('Settings')
    expect(page).to have_no_text('find anything')
  end

  it 'marks the model being looked at' do
    render_inline(described_class.new(user: user, current: :cases))

    expect(page).to have_css('.mg-model.is-current .mg-model__name', text: 'Case')
    expect(page.all('.mg-model.is-current').size).to eq(1)
  end

  it 'counts the hidden posts separately in the hint' do
    create(:post, :inactive)

    render_inline(described_class.new(user: user, current: :posts))

    expect(page).to have_css('.mg-model__hint', text: '2 published · 1 hidden')
  end

  it 'shows who is signed in' do
    render_inline(described_class.new(user: user, current: :posts))

    expect(page).to have_css('.mg-avatar', text: user.nickname.first.upcase)
    expect(page).to have_css('.mg-sidebar__name', text: user.nickname)
    expect(page).to have_css('.mg-sidebar__role', text: 'admin')
  end

  # The rail. 232px of navigation you are not reading while you write, and no way to get it
  # back until now.
  it 'offers a toggle that names what it controls' do
    render_inline(described_class.new(user: user, current: :posts))

    toggle = page.find('.mg-sidebar__toggle')
    expect(toggle['aria-controls']).to eq('mg-sidebar-nav')
    expect(toggle['aria-expanded']).to eq('true')
    # title alone is not an accessible name, which is the exact defect handoff §11 flags.
    expect(toggle['aria-label']).to eq(I18n.t('management.sidebar_component.collapse'))
    expect(page).to have_css('#mg-sidebar-nav')
  end

  # Collapsed, the names are hidden with CSS rather than dropped, so a screen reader and a
  # hover tooltip both still say which screen each dot is.
  it 'keeps every entry nameable when the rail is shut' do
    render_inline(described_class.new(user: user, current: :posts))

    titles = page.all('.mg-model').pluck('title')
    expect(titles).to eq(%w[Post Case Tag Statistics])
  end
end
