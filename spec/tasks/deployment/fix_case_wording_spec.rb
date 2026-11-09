# frozen_string_literal: true

require 'rails_helper'

RSpec::Matchers.define_negated_matcher :not_include, :include

RSpec.describe 'after_party:fix_case_wording' do
  let(:task) { 'after_party:fix_case_wording' }

  def json_columns = Case.columns.select { |column| column.type == :jsonb }.map(&:name)

  def stored_json(kase, name)
    raw = kase.read_attribute_before_type_cast(name)
    raw.is_a?(String) ? raw : raw.to_json
  end

  # Every JSON field of a case as one string, both languages.
  def text_of(slug)
    kase = Case.find_by!(slug: slug)
    json_columns.map { |name| stored_json(kase, name) }.join
  end

  # Swaps a phrase in every JSON field of a case, straight in the table.
  def swap(slug, from, to)
    kase = Case.find_by!(slug: slug)
    kase.update_columns(json_columns.index_with { |name| JSON.parse(stored_json(kase, name).gsub(from, to)) })
  end

  # The table as production holds it: imported before the wording was fixed in the yaml.
  before do
    Cases::Importer.call(force: false)
    swap('intelligence', 'що ви існуєте.', 'що ти існуєш.')
    swap('intelligence', 'connects_to</code>: ролі,', 'connects_to</code>: роли,')
    swap('wardybot', 'мультитенантність не звели', 'модель оренди не звели')
    swap('rubycoin', '53 МБ резидентної пам’яті', '53 МБ resident')
    swap('rubycoin', 'резидентна пам’ять', 'resident-пам’ять')
    swap('intelligence', 'then reworked and dropped', 'then reworked out and dropped')
    swap('wardybot', '"1,000+"', '"1000+"')
    swap('wardybot', '"1 000+"', '"1000+"')
  end

  it 'replaces the old phrases where they are, and records itself' do
    run = run_task(task)

    expect(run.stdout).to include('case wording fixed in:', 'intelligence', 'wardybot', 'rubycoin')
    expect(text_of('intelligence')).to include('що ви існуєте.', 'ролі,').and not_include('роли,')
    expect(text_of('wardybot')).to include('мультитенантність').and not_include('модель оренди')
    expect(text_of('rubycoin')).to include('53 МБ резидентної пам’яті')
      .and not_include('МБ resident', 'resident-пам’ять')
    expect(AfterParty::TaskRecord.where(version: '20261109120000').count).to eq(1)
  end

  it 'fixes English phrases too, and a metric value in each language’s own format' do
    run_task(task)

    expect(text_of('intelligence')).to include('then reworked and dropped')
    expect(text_of('wardybot')).to include('"1,000+"', '"1 000+"').and not_include('"1000+"')
  end

  it 'leaves a phrase the admin has already rewritten, and finds nothing on a second pass' do
    swap('wardybot', 'модель оренди', 'модель власника')

    run_task(task)
    expect(text_of('wardybot')).to include('модель власника').and not_include('мультитенантність')

    AfterParty::TaskRecord.delete_all
    expect(run_task(task).stdout).to include('case wording fixed in: none')
  end
end
