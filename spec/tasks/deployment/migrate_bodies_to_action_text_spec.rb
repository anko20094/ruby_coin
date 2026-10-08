# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'after_party:migrate_bodies_to_action_text' do
  let(:task) { 'after_party:migrate_bodies_to_action_text' }
  let(:recorded) { AfterParty::TaskRecord.where(version: '20260822081500') }

  def legacy_post(english: '<p>English body</p>', ukrainian: '<p>Українська стаття</p>')
    post = create(:post)
    ActionText::RichText.where(record: post).delete_all
    post.update_columns(search_body_en: nil, search_body_uk: nil)
    { 'en' => english, 'uk' => ukrainian }.each do |locale, body|
      PostTranslation.find_or_create_by!(post_id: post.id, locale: locale).update_columns(description: body)
    end
    post.reload
  end

  def body_of(post, locale) = post.reload.rich_body(locale).body

  def row_of(post) = Post.where(id: post.id).pick(:photo, :slug, :main_post)

  it 'writes both languages of a post, though a post with only one of them is invalid' do
    post = legacy_post

    run = run_task(task)

    expect(run.stdout).to include('bodies written: 2')
    expect(body_of(post, :en).to_plain_text).to eq('English body')
    expect(body_of(post, :uk).to_plain_text).to eq('Українська стаття')
  end

  it 'names the bodies that show an image over plain http, which the https site will block' do
    post = legacy_post(english: '<p>x<img src="http://old.example/a.png"><img src="https://ok.example/b.png"></p>')

    run = run_task(task)

    expect(run.stdout).to include("#{post.id}/en: http://old.example/a.png")
    expect(run.stdout).not_to include('https://ok.example/b.png')
    expect(recorded.count).to eq(1)
  end

  it 'mirrors each body into the column search reads' do
    post = legacy_post

    run_task(task)

    expect(post.reload.search_body_en).to eq('English body')
    expect(post.search_body_uk).to eq('Українська стаття')
  end

  it 'moves the body of a post whose cover is gone, which Post validations would refuse' do
    post = legacy_post
    post.update_columns(photo: nil)

    run = run_task(task)

    expect(run.stdout).to include('bodies written: 2')
    expect(body_of(post, :en).to_plain_text).to eq('English body')
  end

  it 'leaves the cover and the featuring of the post as they were' do
    post = legacy_post
    other = create(:post, :main_post)
    before = [row_of(post), row_of(other)]

    run_task(task)

    expect([row_of(post), row_of(other)]).to eq(before)
  end

  it 'records itself, so the deploy does not run it twice' do
    legacy_post

    run_task(task)

    expect(recorded.count).to eq(1)
  end

  it 'counts the languages a post has no legacy body in, and names the one-language posts' do
    post = legacy_post(ukrainian: '')

    run = run_task(task)

    expect(run.stdout).to include('no legacy body: 1', "only one language: #{post.id}")
    expect(body_of(post, :uk)).to be_blank
  end

  it 'skips a body that is already there, and overwrites it under FORCE' do
    post = legacy_post
    ActionText::RichText.create!(record: post, name: 'description_en', body: '<p>Edited since</p>')

    expect(run_task(task).stdout).to include('already present: 1', 'bodies written: 1')
    expect(body_of(post, :en).to_plain_text).to eq('Edited since')

    with_env(FORCE: '1')
    expect(run_task(task).stdout).to include('bodies written: 2')
    expect(body_of(post, :en).to_plain_text).to eq('English body')
  end

  it 'names the markup the sanitiser dropped' do
    post = legacy_post(english: '<p>Kept</p><center>centred</center><script>alert(1)</script>')

    expect(run_task(task).stdout).to match(%r{markup dropped: #{post.id}/en: lost .*script})
  end

  context 'when one post cannot be written' do
    let!(:good) { legacy_post }
    let!(:bad) { legacy_post }
    let(:run) { run_task(task) }

    before do
      allow_any_instance_of(Post).to receive(:update_columns).and_wrap_original do |original, *args|
        raise ActiveRecord::StatementInvalid, 'boom' if original.receiver == bad

        original.call(*args)
      end
    end

    it 'still writes every other post, and prints the whole report' do
      expect(run.stdout).to include('bodies written: 2', 'markup dropped: none')
      expect(body_of(good, :en).to_plain_text).to eq('English body')
    end

    it 'names the post it could not write, and exits non-zero' do
      expect(run.exit_status).to eq(1)
      expect(run.stderr).to include("#{bad.id}: ActiveRecord::StatementInvalid")
    end

    it 'does not record itself, so the next deploy picks the post up again' do
      run

      expect(recorded).to be_empty
    end

    it 'writes neither language of the post it could not write' do
      run

      expect(body_of(bad, :en)).to be_blank
      expect(body_of(bad, :uk)).to be_blank
    end
  end
end
