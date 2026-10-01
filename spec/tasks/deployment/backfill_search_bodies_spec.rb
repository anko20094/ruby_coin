# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'after_party:backfill_search_bodies_with_journal_blocks' do
  include_context 'when carrierwave cleanup'

  let(:task) { 'after_party:backfill_search_bodies_with_journal_blocks' }
  let(:block) { JournalBlock.create!(kind: 'code', payload: { 'source' => 'def backfilltoken; end' }) }
  let(:body) { %(<p>intro</p><action-text-attachment sgid="#{block.attachable_sgid}"></action-text-attachment>) }
  let(:post_record) { I18n.with_locale(:en) { create(:post, description_en: body) } }

  def make_stale(post)
    post.update_columns(search_body_en: 'intro', updated_at: 1.year.ago)
  end

  it 'puts the text of a block into the stored search body, without moving the post date' do
    make_stale(post_record)
    before = post_record.reload.updated_at

    run = run_task(task)

    expect(Post.search_everywhere('backfilltoken')).to include(post_record)
    expect(post_record.reload.updated_at).to eq(before)
    expect(run.stdout).to include('search bodies rewritten on 1 posts')
    expect(AfterParty::TaskRecord.where(version: '20261001120000').count).to eq(1)
  end

  it 'does not unfeature a featured post when it saves another one' do
    featured = create(:post, main_post: true)
    other = create(:post)
    make_stale(other)
    featured.update_columns(main_post: true)
    other.update_columns(main_post: true)

    run_task(task)

    expect(Post.where(main_post: true).count).to eq(2)
  end
end
