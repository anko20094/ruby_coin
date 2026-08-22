# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CVProfile do
  include_context 'when the cv is imported'

  describe '.current' do
    it 'returns the one row there is' do
      expect(described_class.current).to eq(described_class.first)
    end

    it 'hands back an unsaved row on an empty table, so the page still renders' do
      described_class.delete_all

      expect(described_class.current).to be_new_record
      expect(described_class.current.name).to be_nil
    end
  end

  describe 'localised scalars' do
    it 'returns the current locale' do
      I18n.with_locale(:en) { expect(described_class.current.name).to eq('Danyil Shkoropad') }
      I18n.with_locale(:uk) { expect(described_class.current.name).to eq('Данило Шкоропад') }
    end

    it 'refuses a scalar written in one language only' do
      profile = described_class.current
      profile.summary = { 'en' => 'only english' }

      expect(profile).not_to be_valid
      expect(profile.errors.attribute_names).to include(:summary)
    end
  end

  describe 'contact rows' do
    it 'keeps key, label and href in the order they are printed' do
      expect(described_class.current.contact_rows.first).to eq(%w[email anko20094@gmail.com mailto:anko20094@gmail.com])
    end

    it 'takes the indexed rows a form sends and drops the empty one' do
      profile = described_class.current
      profile.contact_rows = {
        '1' => { 'key' => 'telegram', 'label' => '@x', 'href' => 'https://t.me/x' },
        '0' => { 'key' => 'email', 'label' => 'a@b.c', 'href' => 'mailto:a@b.c' },
        '2' => { 'key' => '', 'label' => '', 'href' => '' }
      }

      expect(profile.contact_rows).to eq([%w[email a@b.c mailto:a@b.c], ['telegram', '@x', 'https://t.me/x']])
    end
  end

  describe '#portrait' do
    it 'finds the photograph that is in place' do
      expect(described_class.current.portrait).to eq('work-portrait.jpg')
    end
  end
end
