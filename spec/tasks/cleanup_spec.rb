# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'cleanup:editor_orphans' do # rubocop:disable RSpec/DescribeClass
  include_context 'when carrierwave cleanup'

  def block(age: 8.days)
    JournalBlock.create!(kind: 'callout', payload: { 'body' => 'x' }, created_at: age.ago)
  end

  def image(age: 8.days)
    blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new('png'), filename: 'shot.png',
                                                  content_type: 'image/png')
    blob.update_columns(created_at: age.ago)
    blob
  end

  def blob_path(blob) = Rails.application.routes.url_helpers.rails_blob_path(blob, only_path: true)

  let!(:kept_block) { block }
  let!(:kept_image) { image }
  let!(:orphan_block) { block }
  let!(:orphan_image) { image }
  let!(:fresh_block) { block(age: 1.day) }
  let!(:fresh_image) { image(age: 1.day) }

  before do
    body = %(<p>text</p><action-text-attachment sgid="#{kept_block.attachable_sgid}"></action-text-attachment>) +
           %(<p><img src="#{blob_path(kept_image)}"></p>)
    create(:post, description_en: body)
  end

  it 'only says what it would delete by default' do
    run = run_task('cleanup:editor_orphans')

    expect(run.stdout).to include("would delete 1 journal blocks older than 7 days: #{orphan_block.id}",
                                  "would delete 1 editor images older than 7 days: #{orphan_image.id}", '[dry run]')
    expect(JournalBlock.exists?(orphan_block.id)).to be(true)
    expect(ActiveStorage::Blob.exists?(orphan_image.id)).to be(true)
  end

  it 'deletes the orphans with DRY_RUN=0, and nothing a body still names or an editor may still save' do
    with_env(DRY_RUN: '0')

    run_task('cleanup:editor_orphans')

    expect(JournalBlock.where(id: [orphan_block.id])).to be_empty
    expect(ActiveStorage::Blob.where(id: [orphan_image.id])).to be_empty
    expect(JournalBlock.where(id: [kept_block.id, fresh_block.id]).count).to eq(2)
    expect(ActiveStorage::Blob.where(id: [kept_image.id, fresh_image.id]).count).to eq(2)
  end

  it 'takes the age from DAYS' do
    with_env(DAYS: '0')

    run = run_task('cleanup:editor_orphans')

    expect(run.stdout).to include('would delete 2 journal blocks older than 0 days')
  end

  it 'keeps an image a case field points at' do
    Case.create!(slug: 'scratch', mark: '09', position: 9,
                 **Case::LOCALISED_SCALARS.index_with { { 'en' => 'x', 'uk' => 'х' } },
                 title: { 'en' => %(<img src="#{blob_path(orphan_image)}">), 'uk' => 'х' })

    expect(Editor::Orphans.call.blobs).to be_empty
  end
end
