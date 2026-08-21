# frozen_string_literal: true

require 'rails_helper'

describe PortfolioHelper do
  describe '#t_field' do
    it 'picks the half matching the current locale' do
      I18n.with_locale(:uk) { expect(helper.t_field({ 'en' => 'work', 'uk' => 'роботи' })).to eq('роботи') }
    end

    it 'falls back to English when the locale is missing' do
      I18n.with_locale(:uk) { expect(helper.t_field({ 'en' => 'work' })).to eq('work') }
    end

    it 'passes plain strings through' do
      expect(helper.t_field('proptech · usa')).to eq('proptech · usa')
    end

    it 'passes nil through' do
      expect(helper.t_field(nil)).to be_nil
    end
  end

  describe '#rich' do
    it 'keeps the three inline tags the content relies on' do
      value = { 'en' => 'a <b>bold</b> <i>number</i> in <code>upsert_all</code>' }

      expect(helper.rich(value)).to eq('a <b>bold</b> <i>number</i> in <code>upsert_all</code>')
    end

    it 'strips anything else' do
      expect(helper.rich({ 'en' => '<script>alert(1)</script><a href="/x">link</a>' })).to eq('alert(1)link')
    end
  end
end
