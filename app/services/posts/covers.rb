# frozen_string_literal: true

module Posts
  module Covers
    # Every version name the old uploader cut, current ones included: a `medium_` beside the
    # original that is not the current medium path is a leftover.
    LEGACY_PREFIXES = %w[lite thumb large medium small].freeze

    Result = Struct.new(:rebuilt, :without_cover, :missing, :failed) do
      def initialize = super(0, 0, [], {})
    end

    module_function

    # Normalises each original that is not normalised yet and cuts its two versions. A post that
    # fails is collected with its message, and the rest carry on. `write: false` only counts.
    def rebuild(posts, write: true, log: $stderr)
      posts.find_each.each_with_object(Result.new) do |post, result|
        rebuild_one(post, result, write:, log:)
      end
    end

    def rebuild_one(post, result, write:, log:)
      return result.without_cover += 1 if post[:photo].blank?

      if post.photo.blank?
        log.puts "  post ##{post.id} (#{post.slug}): the file #{post[:photo]} is missing"
        return result.missing << post.id
      end

      if write
        post.photo.normalize unless post.photo.normalized?
        post.photo.recreate_versions!(:medium, :small)
      end
      result.rebuilt += 1
    rescue CarrierWave::ProcessingError, CarrierWave::IntegrityError, ImageProcessing::Error,
           MiniMagick::Error, MiniMagick::Invalid => e
      log.puts "  post ##{post.id} (#{post.slug}): #{e.class} — #{e.message}"
      result.failed[post.id] = e.message
    end

    # The old uploader's version files beside a cover, or nothing while the current versions are
    # not there yet: a cover that failed to rebuild keeps the only resized copies it has.
    def legacy_versions(post)
      return [] if post.photo.blank?

      current = [post.photo, post.photo.medium, post.photo.small].map { |file| file.path.to_s }
      return [] unless current.all? { |path| File.file?(path) }

      pattern = File.join(File.dirname(current.first), "{#{LEGACY_PREFIXES.join(',')}}_*")
      Dir.glob(pattern).select { |path| File.file?(path) } - current
    end

    # `IDS=3,7` from the environment, or every post.
    def scope(ids)
      list = ids.to_s.split(/[\s,]+/).compact_blank
      list.empty? ? Post.all : Post.where(id: list.map { |id| Integer(id) })
    end
  end
end
