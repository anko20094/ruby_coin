# frozen_string_literal: true

# search_body_* is stored, and until journal blocks were part of it a post's copy left them out.
# Saving a post again is what rebuilds the copy, so this saves each one without touching its date.
namespace :after_party do
  desc 'Deployment task: backfill_search_bodies_with_journal_blocks'
  task backfill_search_bodies_with_journal_blocks: :environment do
    rewritten = Post.find_each.count do |post|
      post.save!(validate: false, touch: false)
      post.saved_change_to_search_body_en? || post.saved_change_to_search_body_uk?
    end

    puts "search bodies rewritten on #{rewritten} posts"
    AfterParty::TaskRecord.create(version: AfterParty::TaskRecorder.new(__FILE__).timestamp)
  end
end
