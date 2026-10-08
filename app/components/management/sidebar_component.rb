# frozen_string_literal: true

class Management::SidebarComponent < ViewComponent::Base
  Model = Struct.new(:key, :label, :path, :total, :hint, keyword_init: true) do
    def current?(key_in_view) = key == key_in_view
  end

  # Which controller lights which entry up.
  ENTRY_FOR_CONTROLLER = {
    'posts' => :posts,
    'cases' => :cases,
    'tags' => :tags,
    'statistics' => :statistics
  }.freeze

  attr_reader :user

  def initialize(user:, current: nil)
    @user = user
    @current = current

    super()
  end

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
      Model.new(key: :posts, label: t('.post'), path: helpers.management_posts_path,
                total: numbers[:posts], hint: t('.posts_hint', **numbers[:posts_by_status])),
      Model.new(key: :cases, label: t('.case'), path: helpers.management_cases_path,
                total: numbers[:cases], hint: t('.cases_hint', own: numbers[:own_cases])),
      Model.new(key: :tags, label: t('.tag'), path: helpers.management_tags_path,
                total: numbers[:tags], hint: t('.tags_hint', used: numbers[:used_tags]))
    ]
  end

  def system_entries
    [
      Model.new(key: :statistics, label: t('.statistics'), path: helpers.management_statistics_path,
                total: nil, hint: t('.statistics_hint'))
    ]
  end

  def link_attributes(entry)
    here = entry.current?(current)

    { class: class_names('mg-model', 'is-current': here), title: entry.label, aria: { current: ('page' if here) } }
  end

  def initial
    user&.nickname.to_s.first.to_s.upcase.presence || '·'
  end

  # Whether the rail starts shut. Read from the request rather than restored by JavaScript on
  # connect: the admin bundle is deferred, so that would flash the sidebar open on every page
  # load. See app/javascript/admin/sidebar_controller.js.
  def collapsed?
    helpers.management_sidebar_collapsed?
  end

  private

  # One cache entry for all the numbers, so a page that only needs its own content pays for
  # its own content. Written outside the locale key on purpose: they are numbers.
  def counts
    Rails.cache.fetch('management/sidebar/counts', expires_in: COUNTS_TTL) do
      by_status = helpers.respond_to?(:post_counts) ? helpers.post_counts : Post.group(:status).count

      {
        posts: by_status.values.sum,
        posts_by_status: { active: by_status['active'].to_i, inactive: by_status['inactive'].to_i },
        cases: Case.count,
        own_cases: Case.where(own: true).count,
        tags: Tag.count,
        used_tags: Tag.joins(:posts).distinct.count
      }
    end
  end
end
