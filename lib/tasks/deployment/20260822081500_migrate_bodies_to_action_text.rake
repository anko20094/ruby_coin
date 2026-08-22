# frozen_string_literal: true

# Moves the journal bodies from post_translations.description (Globalize, written by the old
# TinyMCE form) into the two named Action Text rich texts on Post.
#
#   DRY_RUN=1 bin/rails after_party:run  — report only, write nothing
#   FORCE=1                              — overwrite rich texts that already have a body
#
# Action Text sanitises on save, so a body can survive with less markup than it had. The
# report names every post that lost tags and every post that lost text, because those are
# two different problems: dropped tags are a formatting regression, dropped text is data loss.
namespace :after_party do
  desc 'Deployment task: migrate_bodies_to_action_text'
  task migrate_bodies_to_action_text: :environment do
    dry_run = ENV['DRY_RUN'].present?
    force = ENV['FORCE'].present?

    def text_of(html)
      Nokogiri::HTML5.fragment(html.to_s).text.gsub(/\s+/, ' ').strip
    end

    def tags_of(html)
      Nokogiri::HTML5.fragment(html.to_s).css('*').map(&:name).tally
    end

    stats = { written: 0, skipped_present: 0, skipped_blank: 0, text_loss: [], tag_loss: [], one_language: [] }

    Post.find_each do |post|
      present_locales = []

      I18n.available_locales.each do |locale|
        legacy = post.post_translations.find_by(locale:)&.description

        if legacy.blank?
          stats[:skipped_blank] += 1
          next
        end

        present_locales << locale
        field = Post::RICH_TEXT_BODIES.fetch(locale)

        if post.public_send(:"rich_text_#{field}")&.body.present? && !force
          stats[:skipped_present] += 1
          next
        end

        unless dry_run
          post.public_send(:"#{field}=", legacy)
          post.save!
          post.reload
        end

        stored = post.rich_body(locale).body.to_s
        stats[:written] += 1

        before_text = text_of(legacy)
        after_text = dry_run ? before_text : text_of(stored)
        stats[:text_loss] << "#{post.id}/#{locale}: #{before_text.size} → #{after_text.size} chars" if before_text != after_text

        next if dry_run

        lost = tags_of(legacy).reject { |tag, count| tags_of(stored)[tag].to_i >= count }
        stats[:tag_loss] << "#{post.id}/#{locale}: lost #{lost.keys.join(', ')}" if lost.any?
      end

      stats[:one_language] << post.id if present_locales.size == 1
    end

    puts "#{'[dry run] ' if dry_run}bodies written: #{stats[:written]}, " \
         "already present: #{stats[:skipped_present]}, no legacy body: #{stats[:skipped_blank]}"
    puts "posts with only one language: #{stats[:one_language].join(', ').presence || 'none'}"
    puts "text changed: #{stats[:text_loss].presence&.join("\n  ") || 'none'}"
    puts "markup dropped: #{stats[:tag_loss].presence&.join("\n  ") || 'none'}"

    AfterParty::TaskRecord.create(version: AfterParty::TaskRecorder.new(__FILE__).timestamp) unless dry_run
  end
end
