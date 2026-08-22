# frozen_string_literal: true

module Admin::ListsHelper
  # A sortable column header. Clicking the column already sorted flips the direction, and the
  # link carries the current filter and query so sorting never silently resets them.
  def mg_sort_link(label, key, path:)
    current = params[:sort].presence == key || (params[:sort].blank? && key == 'updated')
    direction = current && params[:direction] != 'asc' ? 'asc' : 'desc'

    link_to path.call(sort: key, direction: direction),
            class: "mg-table__sort #{'is-current' if current}" do
      safe_join([label, (tag.span(direction == 'asc' ? '↑' : '↓', class: 'mg-table__arrow') if current)].compact, ' ')
    end
  end

  def mg_status_pill(status)
    tag.span(class: "mg-status mg-status--#{status}") do
      safe_join([tag.span(class: 'mg-status__dot'), t("management.posts.index.statuses.#{status}")])
    end
  end

  def mg_language_pair(locales)
    tag.div(class: 'mg-langs') do
      safe_join(I18n.available_locales.map do |locale|
        tag.span(locale, class: "mg-lang #{'is-present' if locales.include?(locale)}")
      end)
    end
  end
end
