# frozen_string_literal: true

# Moves the journal bodies from post_translations.description (Globalize, written by the old
# TinyMCE form) into the two named Action Text rich texts on Post.
#
#   FORCE=1  — overwrite rich texts that already have a body
#
# Action Text sanitises on save, so a body can survive with less markup than it had. The
# report names every post that lost tags and every post that lost text, because those are
# two different problems: dropped tags are a formatting regression, dropped text is data loss.
#
# Writes the rich texts directly, not through Post#save, so a post that fails the model's
# validations cannot stop the ones after it. Failures are listed and the task exits non-zero.
namespace :after_party do
  desc 'Deployment task: migrate_bodies_to_action_text'
  task migrate_bodies_to_action_text: :environment do
    force = ENV['FORCE'].present?
    text_of = ->(html) { Nokogiri::HTML5.fragment(html.to_s).text.gsub(/\s+/, ' ').strip }
    tags_of = ->(html) { Nokogiri::HTML5.fragment(html.to_s).css('*').map(&:name).tally }

    stats = {
      written: 0, skipped_present: 0, skipped_blank: 0,
      text_loss: [], tag_loss: [], one_language: [], failed: []
    }

    Post.find_each do |post|
      bodies = I18n.available_locales.index_with { |locale| post.post_translations.find_by(locale:)&.description }
      legacy = bodies.compact_blank

      stats[:skipped_blank] += bodies.size - legacy.size
      stats[:one_language] << post.id if legacy.size == 1

      pending = legacy.reject do |locale, _body|
        field = Post::RICH_TEXT_BODIES.fetch(locale)
        post.public_send(:"rich_text_#{field}")&.body.present? && !force
      end
      stats[:skipped_present] += legacy.size - pending.size

      stored = {}
      begin
        Post.transaction(requires_new: true) do
          pending.each do |locale, body|
            field = Post::RICH_TEXT_BODIES.fetch(locale)
            rich_text = post.public_send(:"rich_text_#{field}") || post.public_send(:"build_rich_text_#{field}")
            rich_text.update!(body:)
            stored[locale] = rich_text.reload.body
            post.update_columns("search_body_#{locale}": stored[locale].to_plain_text)
          end
        end
      rescue ActiveRecord::ActiveRecordError => e
        stats[:failed] << "#{post.id}: #{e.class} — #{e.message.squish}"
        next
      end

      pending.each do |locale, body|
        saved = stored.fetch(locale).to_s
        stats[:written] += 1

        before_text = text_of.call(body)
        after_text = text_of.call(saved)
        stats[:text_loss] << "#{post.id}/#{locale}: #{before_text.size} → #{after_text.size} chars" if before_text != after_text

        lost = tags_of.call(body).reject { |tag, count| tags_of.call(saved)[tag].to_i >= count }
        stats[:tag_loss] << "#{post.id}/#{locale}: lost #{lost.keys.join(', ')}" if lost.any?
      end
    end

    puts "bodies written: #{stats[:written]}, " \
         "already present: #{stats[:skipped_present]}, no legacy body: #{stats[:skipped_blank]}"
    puts "posts with only one language: #{stats[:one_language].join(', ').presence || 'none'}"
    puts "text changed: #{stats[:text_loss].presence&.join("\n  ") || 'none'}"
    puts "markup dropped: #{stats[:tag_loss].presence&.join("\n  ") || 'none'}"

    abort "posts that could not be written:\n  #{stats[:failed].join("\n  ")}" if stats[:failed].any?

    AfterParty::TaskRecord.create(version: AfterParty::TaskRecorder.new(__FILE__).timestamp)
  end
end
