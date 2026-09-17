# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Case do
  include_context 'when the cases are imported'

  describe 'validations' do
    subject(:kase) { described_class.new(slug: 'x', mark: '08', position: 8) }

    it { is_expected.to validate_presence_of(:mark) }

    it 'insists on a url-safe slug' do
      expect(described_class.new(slug: 'Not A Slug', mark: '08', position: 8)).not_to be_valid
    end

    it 'refuses a second case on the same slug' do
      expect(described_class.new(slug: 'dna', mark: '08', position: 8)).not_to be_valid
    end

    # The handoff's editorial rule: never one language alone.
    it 'refuses a scalar written in only one language' do
      described_class::LOCALISED_SCALARS.each { |field| kase.public_send(:"#{field}_en=", 'x') }

      expect(kase).not_to be_valid
      expect(kase.errors.attribute_names).to include(*described_class::LOCALISED_SCALARS)

      described_class::LOCALISED_SCALARS.each { |field| kase.public_send(:"#{field}_uk=", 'ікс') }

      expect(kase).to be_valid
    end
  end

  describe 'localised readers' do
    let(:dna) { described_class.find_by!(slug: 'dna') }

    it 'returns the current locale and keeps the raw hash reachable' do
      I18n.with_locale(:en) { expect(dna.title).to eq('DNA') }
      I18n.with_locale(:uk) { expect(dna.title).to eq(dna[:title]['uk']) }

      expect(dna[:title].keys).to contain_exactly('en', 'uk')
    end

    it 'falls back to the default locale rather than rendering nothing' do
      dna.update_columns(tagline: { I18n.default_locale.to_s => 'тільки одна мова' })

      I18n.with_locale(:en) { expect(dna.reload.tagline).to eq('тільки одна мова') }
    end

    it 'gives the admin form one accessor per language' do
      dna.title_en = 'Renamed'

      expect(dna[:title]['en']).to eq('Renamed')
      expect(dna[:title]['uk']).to be_present
    end
  end

  describe 'structured readers' do
    let(:kase) { described_class.find_by!(slug: 'intelligence') }

    it 'localises both halves of a metric' do
      I18n.with_locale(:en) do
        expect(kase.metrics.size).to eq(4)
        expect(kase.metrics.first[:value]).to eq(kase[:metrics].first['value']['en'])
        expect(kase.metrics.first[:label]).to eq(kase[:metrics].first['label']['en'])
      end
    end

    # Ukrainian groups thousands with a space and takes the comma for the decimal, so the figure
    # is translated as surely as the words beside it.
    it 'prints a figure the way the language writes it' do
      rubycoin = described_class.find_by!(slug: 'rubycoin')

      expect(I18n.with_locale(:en) { rubycoin.metrics.second[:value] }).to eq('31k')
      expect(I18n.with_locale(:uk) { rubycoin.metrics.second[:value] }).to eq('31 тис.')
    end

    it 'localises both halves of an engineering card' do
      I18n.with_locale(:uk) do
        card = kase.engineering_items.first

        expect(card[:title]).to eq(kase[:engineering_items].first['title']['uk'])
        expect(card[:body]).to eq(kase[:engineering_items].first['body']['uk'])
      end
    end

    it 'returns plain arrays of strings where the content is plain' do
      I18n.with_locale(:en) do
        expect(kase.plain_body.size).to eq(3)
        expect(kase.plain_body).to all(be_a(String))
        expect(kase.mine).to all(be_a(String))
        expect(kase.stack).to all(be_a(String))
      end
    end
  end

  describe '#neighbours' do
    it 'returns the previous and the next case' do
      previous_case, next_case = described_class.find_by!(slug: 'wardybot').neighbours

      expect([previous_case.slug, next_case.slug]).to eq(%w[dna leads])
    end

    it 'wraps at both ends of the list' do
      expect(described_class.find_by!(slug: 'rubycoin').neighbours.map(&:slug)).to eq(%w[chatgpt intelligence])
      expect(described_class.find_by!(slug: 'intelligence').neighbours.first.slug).to eq('rubycoin')
    end

    it 'points a lone case at itself rather than raising' do
      described_class.where.not(slug: 'dna').delete_all
      dna = described_class.find_by!(slug: 'dna')

      expect(dna.neighbours).to eq([dna, dna])
    end
  end

  describe '#number' do
    it 'is the position in the list, counting from one' do
      expect(described_class.find_by!(slug: 'intelligence').number).to eq(1)
      expect(described_class.find_by!(slug: 'rubycoin').number).to eq(7)
    end
  end

  describe '.find_by_slug!' do
    it 'raises for a slug that is not there' do
      expect { described_class.find_by!(slug: 'nope') }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  # StructuredJson's form-facing half, exercised here because Case is the model that still has
  # a form. The CV reads structured fields but no longer writes them: it has no screen — it is
  # config/portfolio/cv.yml, imported by `rake cv:import`.
  describe 'the structured rows a form posts' do
    let(:kase) { described_class.ordered.first }

    it 'takes the indexed rows in index order, not in the order they arrive' do
      kase.mine_rows = {
        '1' => { 'en' => 'second', 'uk' => 'друге' },
        '0' => { 'en' => 'first', 'uk' => 'перше' }
      }

      expect(kase.mine_rows.pluck('en')).to eq(%w[first second])
    end

    it 'drops a row the author left empty, and keeps one that has anything at all' do
      kase.mine_rows = {
        '0' => { 'en' => '', 'uk' => '' },
        '1' => { 'en' => 'kept', 'uk' => '' }
      }

      expect(kase.mine_rows).to eq([{ 'en' => 'kept', 'uk' => '' }])
    end

    it 'keeps only the keys the shape declares' do
      row = {
        'value' => { 'en' => '2.14M', 'uk' => '2,14 млн' },
        'label' => { 'en' => 'users', 'uk' => 'юзерів' }, 'salary' => 'none'
      }
      kase.metrics_rows = { '0' => row }

      expect(kase.metrics_rows.first.keys).to match_array(%w[value label])
    end
  end
end
