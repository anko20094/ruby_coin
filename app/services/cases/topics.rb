# frozen_string_literal: true

class Cases::Topics
  # What links a case to the journal: the journal's tags read against the case's stack. Tags
  # are single words ("postgres", "hotwire"); a stack item is a line of prose ("PostgreSQL 18",
  # "Hotwire · Stimulus"), so both sides are reduced to the same lower-case keys and compared.
  #
  # A key every case carries is dropped: all seven are Rails, so "rails" would tie each entry to
  # each project and say nothing about which one it is about.
  ALIASES = { 'postgresql' => 'postgres' }.freeze
  POSTS_PER_CASE = 3
  # An entry gets a project link only when this few cases share its best overlap; more than that
  # and no single project is what the entry is about.
  CASES_PER_POST = 2

  private attr_reader :cases

  def initialize(cases)
    @cases = cases.to_a
  end

  def self.key(text)
    squashed = text.to_s.downcase.gsub(/[^a-z0-9_]/, '')
    ALIASES.fetch(squashed) { squashed.delete('_') }
  end

  # Each word of an item, and each "·"-separated part of it squashed, so "Active Record" and
  # "pg_search · Mobility" both reach the keys a tag would be written as.
  def keys_for(kase)
    Array(kase.stack).flat_map { |item| item_keys(item) }.to_set - shared_by_all
  end

  # The readable entries whose tags name this case's stack, most overlapping first.
  def posts_for(kase, locale: I18n.locale)
    tag_ids = tags_matching(keys_for(kase)).map(&:id)
    return Post.none if tag_ids.empty?

    overlap = Post.joins(:tags).where(tags: { id: tag_ids }).group('posts.id')
                  .select('posts.id AS post_id, COUNT(*) AS tag_count')
    Post.active.translated_in(locale)
        .joins("INNER JOIN (#{overlap.to_sql}) overlap ON overlap.post_id = posts.id")
        .reorder(Arel.sql('overlap.tag_count DESC, posts.created_at DESC'))
        .limit(POSTS_PER_CASE)
  end

  # The tags of this entry that tied it to the case.
  def shared_tags(post, kase)
    keys = keys_for(kase)
    post.tags.select { |tag| keys.include?(self.class.key(tag.title)) }
  end

  # The shared tag most of these entries carry (the first by title on a tie): the one that
  # leads on to the rest of the journal on the subject.
  def lead_tag(kase, posts)
    counts = posts.flat_map { |post| shared_tags(post, kase) }.tally
    counts.min_by { |tag, count| [-count, tag.title] }&.first
  end

  # The cases this entry is about, in the order /work lists them; none when the best overlap is
  # shared too widely to point at anything.
  def cases_for(post)
    post_keys = post.tags.to_set { |tag| self.class.key(tag.title) }
    scores = cases.index_with { |kase| (keys_for(kase) & post_keys).size }
    best = scores.values.max.to_i
    return [] if best.zero?

    winners = cases.select { |kase| scores[kase] == best }
    winners.size > CASES_PER_POST ? [] : winners
  end

  private

  def item_keys(item)
    words = item.to_s.downcase.scan(/[a-z][a-z0-9_]*/)
    parts = item.to_s.split(%r{[·/,]})
    (words + parts).map { |text| self.class.key(text) }.grep(/\A[a-z]/)
  end

  def shared_by_all
    @shared_by_all ||=
      if cases.many?
        cases.map { |kase| Array(kase.stack).flat_map { |item| item_keys(item) }.to_set }.reduce(:&)
      else
        Set.new
      end
  end

  def tags_matching(keys)
    return [] if keys.empty?

    Tag.all.select { |tag| keys.include?(self.class.key(tag.title)) }
  end
end
