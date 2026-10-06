# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LocalisedJson do
  def pair(english, ukrainian) = { 'en' => english, 'uk' => ukrainian }

  def kase(**overrides)
    scalars = Case::LOCALISED_SCALARS.index_with { pair('en', 'укр') }

    Case.new(slug: 'scratch', mark: '01', position: 1, **scalars, **overrides)
  end

  describe 'a plain string standing for both languages' do
    it 'is a valid scalar and reads the same in both' do
      kase = kase(role: 'Rails Engineer', year: '2023—2026')

      expect(kase).to be_valid
      expect([kase.role_en, kase.role_uk, kase.year_uk]).to eq(['Rails Engineer', 'Rails Engineer', '2023—2026'])
    end

    it 'still counts an empty one as missing' do
      expect(kase(role: '')).not_to be_valid
      expect(kase(role: pair('only english', ''))).not_to be_valid
    end
  end

  describe Person::CV do
    it 'prints a language pair in a contact row in the current language' do
      cv = described_class.new('contact' => [[pair('email', 'пошта'), pair('write', 'пишіть'), 'mailto:a@b.c']])

      expect(I18n.with_locale(:en) { cv.contact_rows }).to eq([%w[email write mailto:a@b.c]])
      expect(I18n.with_locale(:uk) { cv.contact_rows }).to eq([%w[пошта пишіть mailto:a@b.c]])
    end

    it 'prints a language pair among the items of a stack group, and lets a bare name through' do
      group = { 'label' => 'Skills', 'items' => ['Rails', pair('merge rights', 'право злиття')] }
      cv = described_class.new('stacks' => [group])

      expect(I18n.with_locale(:uk) { cv.stack_groups.first[:items] }).to eq(['Rails', 'право злиття'])
    end

    it 'reads the name cv.yml keeps as two keys as one language pair' do
      cv = described_class.new('name' => 'Danyil', 'nameUk' => 'Даниїл')

      expect(I18n.with_locale(:en) { cv.name }).to eq('Danyil')
      expect(I18n.with_locale(:uk) { cv.name }).to eq('Даниїл')
    end
  end

  describe 'a language pair with no English line' do
    let(:contribution) do
      lines = [pair('a', 'а'), { 'uk' => 'б' }]

      Contribution.new('x', { 'person' => 'a', 'role' => { 'uk' => 'інженер' }, 'did' => lines })
    end

    it 'reads as the Ukrainian line by default, which is what a visitor to /en sees' do
      expect(I18n.with_locale(:en) { contribution.role }).to eq('інженер')
    end

    it 'reads as nothing when the fallback is switched off' do
      expect(I18n.with_locale(:en) { contribution.role(fallback: false) }).to be_nil
      expect(I18n.with_locale(:en) { contribution.did(fallback: false) }).to eq(['a', nil])
    end

    it 'still reads the language it has when the fallback is switched off' do
      expect(I18n.with_locale(:uk) { contribution.role(fallback: false) }).to eq('інженер')
    end

    it 'passes a plain string through, since it stands for both languages' do
      plain = Contribution.new('x', { 'person' => 'a', 'period' => '2024' })

      expect(I18n.with_locale(:en) { plain.period(fallback: false) }).to eq('2024')
    end

    it 'reads a person field the same way' do
      person = Person.new('id' => 'a', 'name' => { 'uk' => 'Привид' })

      expect(I18n.with_locale(:en) { [person.name, person.name(fallback: false)] }).to eq(['Привид', nil])
    end
  end

  describe Contribution do
    it 'prints a period written as a language pair in the current language' do
      contribution = described_class.new('x', { 'person' => 'a', 'period' => pair('2024 — now', '2024 — тепер') })

      expect(I18n.with_locale(:en) { contribution.period }).to eq('2024 — now')
      expect(I18n.with_locale(:uk) { contribution.period }).to eq('2024 — тепер')
    end

    it 'lets a bare period through' do
      expect(described_class.new('x', { 'person' => 'a', 'period' => '2024' }).period).to eq('2024')
    end
  end
end
