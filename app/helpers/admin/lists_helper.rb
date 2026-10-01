# frozen_string_literal: true

module Admin::ListsHelper
  # A sortable column header. Clicking the column already sorted flips the direction, and the
  # link carries the current filter and query so sorting never silently resets them.
  def mg_sort_link(label, key, path:)
    current = mg_sorted_by?(key)
    ascending = params[:direction] == 'asc'
    next_direction = current && !ascending ? 'asc' : 'desc'
    arrow = tag.span(ascending ? '↑' : '↓', class: 'mg-table__arrow', aria: { hidden: true }) if current

    link_to path.call(sort: key, direction: next_direction),
            class: "mg-table__sort #{'is-current' if current}" do
      safe_join([label, arrow].compact, ' ')
    end
  end

  def mg_aria_sort(key)
    return unless mg_sorted_by?(key)

    params[:direction] == 'asc' ? 'ascending' : 'descending'
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

  private

  # While searching without a sort the list is in relevance order, which no column describes.
  def mg_sorted_by?(key)
    params[:sort].presence == key || (params[:sort].blank? && params[:query].blank? && key == 'updated')
  end
end
