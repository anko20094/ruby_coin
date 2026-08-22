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

  def models
    [
      Model.new(key: :posts, label: 'Post', path: helpers.management_posts_path,
                total: Post.count, hint: posts_hint),
      Model.new(key: :cases, label: 'Case', path: helpers.management_cases_path,
                total: Case.count, hint: cases_hint),
      Model.new(key: :cv_blocks, label: 'CVBlock', path: helpers.management_cv_blocks_path,
                total: CVBlock.count, hint: cv_hint),
      Model.new(key: :tags, label: 'Tag', path: helpers.management_tags_path,
                total: Tag.count, hint: tags_hint)
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

  def posts_hint
    by_status = Post.group(:status).count
    t('.posts_hint', active: by_status['active'].to_i, inactive: by_status['inactive'].to_i)
  end

  def cases_hint
    t('.cases_hint', own: Case.where(own: true).count)
  end

  def cv_hint
    CVBlock.group(:kind).count.map { |kind, count| "#{count} #{kind.tr('_', ' ')}" }.join(' · ')
  end

  def tags_hint
    t('.tags_hint', used: Tag.joins(:posts).distinct.count)
  end
end
