# frozen_string_literal: true

# The /management sidebar: the models this admin actually has, with real counts and a one-line
# hint each, then the user.
#
# The design also drew a ⌘K search, and Settings / Users / Audit / Redirect entries. None of
# those exist in this application, and a sidebar that lists screens which are not there is
# worse than a shorter one — so they are not here. When they exist, they belong in this list.
class Management::SidebarComponent < ViewComponent::Base
  Model = Struct.new(:key, :label, :path, :total, :hint, keyword_init: true) do
    def current?(key_in_view) = key == key_in_view
  end

  # Which controller lights which entry up.
  ENTRY_FOR_CONTROLLER = {
    'posts' => :posts,
    'cases' => :cases,
    'cv_blocks' => :cv_blocks,
    'cv_profiles' => :cv_blocks,
    'tags' => :tags,
    'statistics' => :statistics
  }.freeze

  def initialize(user:, current: nil)
    @user = user
    @current = current
    super()
  end

  attr_reader :user

  def current
    @current || ENTRY_FOR_CONTROLLER[helpers.controller_name]
  end

  # How long the counts may be out of date. The sidebar is orientation, not a report: eight
  # COUNT queries were running on every single admin page — more than most of those pages ran
  # for their own content — to keep numbers current to the second that nobody reads that way.
  COUNTS_TTL = 2.minutes

  def models
    numbers = counts

    [
      Model.new(key: :posts, label: 'Post', path: helpers.management_posts_path,
                total: numbers[:posts], hint: t('.posts_hint', **numbers[:posts_by_status])),
      Model.new(key: :cases, label: 'Case', path: helpers.management_cases_path,
                total: numbers[:cases], hint: t('.cases_hint', own: numbers[:own_cases])),
      Model.new(key: :cv_blocks, label: 'CVBlock', path: helpers.management_cv_blocks_path,
                total: numbers[:cv_blocks], hint: numbers[:cv_by_kind]),
      Model.new(key: :tags, label: 'Tag', path: helpers.management_tags_path,
                total: numbers[:tags], hint: t('.tags_hint', used: numbers[:used_tags]))
    ]
  end

  def system_entries
    [
      Model.new(key: :statistics, label: 'Statistics', path: helpers.management_statistics_path,
                total: nil, hint: t('.statistics_hint'))
    ]
  end

  def initial
    user&.nickname.to_s.first.to_s.upcase.presence || '·'
  end

  private

  # One cache entry for all eight numbers, so a page that only needs its own content pays for
  # its own content. Written outside the locale key on purpose: they are numbers.
  def counts
    Rails.cache.fetch('management/sidebar/counts', expires_in: COUNTS_TTL) do
      by_status = Post.group(:status).count

      {
        posts: Post.count,
        posts_by_status: { active: by_status['active'].to_i, inactive: by_status['inactive'].to_i },
        cases: Case.count,
        own_cases: Case.where(own: true).count,
        cv_blocks: CVBlock.count,
        cv_by_kind: CVBlock.group(:kind).count.map { |kind, count| "#{count} #{kind.tr('_', ' ')}" }.join(' · '),
        tags: Tag.count,
        used_tags: Tag.joins(:posts).distinct.count
      }
    end
  end
end
