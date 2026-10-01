# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'after_party:recompress_post_covers' do
  let(:task) { 'after_party:recompress_post_covers' }
  let(:post) { create(:post) }
  let(:recorded) { AfterParty::TaskRecord.where(version: '20260824180000') }

  it 'builds the versions a legacy post has no file for, and records itself' do
    FileUtils.rm_f(post.photo.medium.path)

    run = run_task(task)

    expect(File).to exist(post.reload.photo.medium.path)
    expect(run.stdout).to include('covers rebuilt: 1', 'failed: 0')
    expect(recorded.count).to eq(1)
  end

  it 'counts a post with no cover rather than failing on it' do
    post.update_columns(photo: nil)

    run = run_task(task)

    expect(run.stdout).to include('covers rebuilt: 0', 'without a cover: 1', 'failed: 0')
    expect(recorded.count).to eq(1)
  end

  it 'names a cover whose file is gone and still records itself, since there is nothing to rebuild' do
    FileUtils.rm_f(post.photo.path)

    run = run_task(task)

    expect(run.stderr).to include("post ##{post.id}")
    expect(run.stdout).to include('file missing: 1', 'failed: 0')
    expect(run).not_to be_aborted
    expect(recorded.count).to eq(1)
  end

  it 'names a cover it cannot process and carries on with the rest' do
    bad = post
    create(:post)
    allow_any_instance_of(PhotoUploader).to receive(:recreate_versions!).and_wrap_original do |original, *args|
      raise CarrierWave::ProcessingError, 'boom' if original.receiver.model == bad

      original.call(*args)
    end

    run = run_task(task)

    expect(run.stderr).to include("post ##{bad.id}", 'boom')
    expect(run.stdout).to include('covers rebuilt: 1', 'failed: 1')
    expect(run).to be_aborted
    expect(recorded).to be_empty
  end

  it 'writes nothing to disk under DRY_RUN, counts the covers, and does not record itself' do
    FileUtils.rm_f(post.photo.medium.path)
    with_env(DRY_RUN: '1')

    run = run_task(task)

    expect(File).not_to exist(post.reload.photo.medium.path)
    expect(run.stdout).to include('covers that would be rebuilt: 1')
    expect(recorded).to be_empty
  end
end
