# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Posts::Translator do
  let(:post) { create(:post) }

  def localizations(title:, subtitle:)
    { 'title_localizations' => { 'en' => title }, 'subtitle_localizations' => { 'en' => subtitle } }
  end

  def translate(params)
    I18n.with_locale(:uk) { described_class.call(post, params) }
  end

  it 'puts the other language on the post, for the caller to save in one go' do
    expect(translate(localizations(title: 'English Title', subtitle: 'English Subtitle'))).to be(true)
    post.save!

    english = post.reload.translations.find_by(locale: 'en')
    expect([english.title, english.subtitle]).to eq(['English Title', 'English Subtitle'])
    expect(post.translations.count).to eq(I18n.available_locales.count)
  end

  it 'writes nothing on its own' do
    translate(localizations(title: 'Unsaved', subtitle: 'Unsaved'))

    expect(post.reload.title_en).not_to eq('Unsaved')
  end

  it 'overwrites an earlier translation' do
    translate(localizations(title: 'First', subtitle: 'First'))
    post.save!
    translate(localizations(title: 'Second', subtitle: 'Second'))
    post.save!

    expect(post.reload.title_en).to eq('Second')
  end

  it 'refuses a blank language and says which field it is' do
    expect(translate(localizations(title: '', subtitle: 'Kept'))).to be(false)

    expect(post.errors[:title]).to be_present
    expect(post.errors[:subtitle]).to be_empty
  end

  it 'ignores a locale the site does not have' do
    params = { 'title_localizations' => { 'de' => 'Titel' } }

    expect(translate(params)).to be(true)
    expect(post).not_to respond_to(:title_de=)
  end
end
