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

    # The editorial rule: never one language alone.
    it 'refuses a scalar written in only one language' do
      described_class::LOCALISED_SCALARS.each { |field| kase.public_send(:"#{field}_en=", 'x') }

      expect(kase).not_to be_valid
      expect(kase.errors.attribute_names).to include(*described_class::LOCALISED_SCALARS)

      described_class::LOCALISED_SCALARS.each { |field| kase.public_send(:"#{field}_uk=", 'ікс') }

      expect(kase).to be_valid
    end
  end

  describe 'position' do
    let(:scalars) { described_class::LOCALISED_SCALARS.index_with { { 'en' => 'x', 'uk' => 'ікс' } } }

    def build(position, slug: 'scratch')
      described_class.new(slug: slug, mark: '99', position: position, **scalars)
    end

    it 'is a whole number between one and a million' do
      expect(build(1)).to be_valid

      [0, -1, '1.5', 1_000_000, 99_999_999_999, nil].each do |position|
        expect(build(position)).not_to be_valid, "#{position.inspect} should be refused"
      end
    end

    context 'when two cases share one' do
      before do
        build(50, slug: 'tie-a').save!
        build(50, slug: 'tie-b').save!
      end

      it 'keeps them in the order they were made, however often either is saved' do
        expect(described_class.slugs.last(2)).to eq(%w[tie-a tie-b])

        described_class.find_by!(slug: 'tie-a').update!(mark: '98')

        expect(described_class.slugs.last(2)).to eq(%w[tie-a tie-b])
      end
    end
  end

  describe 'rows in one language only' do
    let(:kase) { described_class.find_by!(slug: 'intelligence') }

    it 'refuses a row of a list written in one language' do
      kase.mine_rows = { '0' => { 'en' => 'only english', 'uk' => '' } }

      expect(kase).not_to be_valid
      expect(kase.errors.where(:mine, :one_language_only)).to be_present
    end

    it 'refuses a half-translated sub-field of a row that has others complete' do
      kase.metrics_rows = {
        '0' => { 'value' => { 'en' => '1', 'uk' => '1' }, 'label' => { 'en' => 'only english', 'uk' => '' } }
      }

      expect(kase).not_to be_valid
      expect(kase.errors.where(:metrics, :one_language_only)).to be_present
    end

    it 'accepts a sub-field left empty in both languages, and a plain string standing for both' do
      kase.metrics_rows = { '0' => { 'value' => { 'en' => '', 'uk' => '' }, 'label' => { 'en' => 'a', 'uk' => 'б' } } }
      kase.update_columns(mine: ['the same in both'])

      expect(kase).to be_valid
    end

    it 'says so in words, in either language' do
      kase.mine_rows = { '0' => { 'en' => 'only english', 'uk' => '' } }

      messages = %i[en uk].index_with do |locale|
        I18n.with_locale(locale) { kase.tap(&:valid?).errors.full_messages.to_sentence }
      end

      expect(messages).to eq(en: 'What was mine has a row written in one language only',
                             uk: 'Що було моїм має рядок, написаний лише однією мовою')
    end
  end

  describe 'a plain string where a language pair is expected' do
    subject(:kase) { described_class.new(year: '2023—2026') }

    it 'reads the same in both languages through the accessors' do
      expect([kase.year_en, kase.year_uk]).to eq(['2023—2026', '2023—2026'])
    end

    it 'becomes a pair when one language is written, keeping the other' do
      kase.year_en = '2023—2027'

      expect(kase[:year]).to eq({ 'en' => '2023—2027', 'uk' => '2023—2026' })
    end

    it 'has no accessors that raise on a column that is still empty' do
      expect(described_class.new.year_en).to be_nil
    end
  end

  describe 'a case the roster names' do
    let(:scratch) do
      described_class.find_by!(slug: 'dna').dup.tap { |copy| copy.slug = 'scratch' }.tap(&:save!)
    end

    it 'keeps its slug, because team.yml credits and CV entries find it by that' do
      credited = described_class.find_by!(slug: 'dna')
      credited.slug = 'renamed'

      expect(credited).not_to be_valid
      expect(credited.errors.where(:slug, :named_elsewhere)).to be_present
    end

    it 'cannot be deleted' do
      credited = described_class.find_by!(slug: 'dna')

      expect(credited.destroy).to be(false)
      expect(credited.errors.where(:slug, :named_elsewhere)).to be_present
      expect(described_class.exists?(credited.id)).to be(true)
    end

    it 'is also named by the career in the CV' do
      allow(Team).to receive(:owner_cv).and_return(Person::CV.new('experience' => [{ 'cases' => ['scratch'] }]))

      expect(scratch.destroy).to be(false)
    end

    it 'is also named by a career entry in people.yml' do
      ghost = Person.new('id' => 'ghost', 'cv' => { 'experience' => [{ 'cases' => ['scratch'] }] })
      allow(Team).to receive(:everyone).and_return(Team.everyone + [ghost])

      expect(scratch.destroy).to be(false)
    end

    it 'leaves a case nobody names free to be renamed and deleted' do
      scratch.update!(slug: 'renamed')

      expect(scratch.destroy).to be_truthy
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
  # config/portfolio/cv.yml.
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

  describe '.first_year' do
    it 'reads a language pair by its values and a bare string as it is' do
      paired = described_class.new(year: { 'en' => '2019—now', 'uk' => '2019—зараз' })
      cases = [paired, described_class.new(year: '2017')]

      expect(described_class.first_year(cases)).to eq('2017')
    end

    it 'answers the same from rows already loaded' do
      expect(described_class.first_year(described_class.all.to_a)).to eq(described_class.first_year)
    end
  end
end
