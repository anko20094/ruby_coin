# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'after_party:run' do # rubocop:disable RSpec/DescribeClass
  let(:task_files) { Rails.root.glob('lib/tasks/deployment/[0-9]*_*.rake') }

  let!(:legacy) do
    post = create(:post)
    ActionText::RichText.where(record: post).delete_all
    post.update_columns(search_body_en: nil, search_body_uk: nil)
    { 'en' => '<p>English body</p>', 'uk' => '<p>Українська стаття</p>' }.each do |locale, body|
      PostTranslation.find_or_create_by!(post_id: post.id, locale: locale).update_columns(description: body)
    end
    post
  end

  it 'runs every task on a legacy-shaped database and records each of them' do
    run = run_task('after_party:run')

    expect(run.aborted?).to be(false)
    expect(AfterParty::TaskRecord.pluck(:version)).to match_array(task_files.map { |file| file.basename.to_s[/\A\d+/] })
    expect(legacy.reload.rich_body(:uk).body.to_plain_text).to eq('Українська стаття')
    expect(Case.count).to eq(7)
  end

  it 'finds nothing to do the second time' do
    run_task('after_party:run')

    expect(run_task('after_party:run').stdout).to include('no pending tasks to run')
  end

  context 'with DRY_RUN' do
    before { with_env(DRY_RUN: '1') }

    it 'prints the reports a real run prints, and says it rolled back' do
      run = run_task('after_party:run')

      expect(run.stdout).to include('[dry run] every task below', 'bodies written: 2', 'cases imported: 7',
                                    'markup dropped:', '[dry run] rolled back')
    end

    it 'writes nothing and records nothing' do
      run_task('after_party:run')

      expect(AfterParty::TaskRecord.count).to eq(0)
      expect([Case.count, ActionText::RichText.count]).to eq([0, 0])
      expect(legacy.reload.search_body_uk).to be_blank
    end

    it 'leaves the same run available for real afterwards' do
      run_task('after_party:run')
      with_env(DRY_RUN: nil)

      run_task('after_party:run')

      expect(Case.count).to eq(7)
      expect(legacy.reload.rich_body(:en).body.to_plain_text).to eq('English body')
    end

    it 'leaves the database untouched even when a task aborts' do
      allow(Cases::Importer).to receive(:call).and_wrap_original do |original, *args, **kwargs|
        original.call(*args, **kwargs)
        Cases::Importer::Result.new(imported: [], kept: [], mismatches: ['dna.mark: expected 2'], strays: [])
      end

      run = run_task('after_party:run')

      expect(run.aborted?).to be(true)
      expect(AfterParty::TaskRecord.count).to eq(0)
    end
  end
end
