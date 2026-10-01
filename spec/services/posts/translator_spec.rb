# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Posts::Translator do
  let(:post) { create(:post) }
  let(:current_post) { post.translations.find_by(locale: 'en') }
  let!(:localization_params) do
    {
      'title_localizations' => { en: 'English Title' },
      'subtitle_localizations' => { en: 'English Subtitle' }
    }
  end

  let!(:updated_params) do
    {
      'title_localizations' => { en: 'Great Title' },
      'subtitle_localizations' => { en: 'Great Subtitle' }
    }
  end

  before do
    I18n.with_locale :uk do
      described_class.call(post, localization_params)
    end
  end

  describe '#call' do
    it 'creates translations for available locales' do
      expect(post.post_translations.count).to eq(I18n.available_locales.count)
    end

    it 'sets the correct attributes in translations' do
      expect(current_post.title).to eq(localization_params.dig('title_localizations', :en))
      expect(current_post.subtitle).to eq(localization_params.dig('subtitle_localizations', :en))
    end
  end

  describe '#call with updated params' do
    before { described_class.call(post, updated_params) }

    it 'updates translations for available locales' do
      expect(post.post_translations.count).to eq(I18n.available_locales.count)
    end

    it 'sets the correct attributes in translations' do
      expect(current_post.title).to eq(updated_params.dig('title_localizations', :en))
      expect(current_post.subtitle).to eq(updated_params.dig('subtitle_localizations', :en))
    end
  end
end
