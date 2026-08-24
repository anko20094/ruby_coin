# frozen_string_literal: true

module ApplicationHelper
  # Pagy 43+: provide compatibility wrapper for existing views
  def pagy_bootstrap_nav(pagy, classes: 'pagination', **)
    pagy.series_nav(:bootstrap, classes:, **).html_safe # rubocop:disable Rails/OutputSafety
  end

  def prepend_flash
    turbo_stream.prepend 'flash', partial: 'shared/flash'
  end

  # The brand in a document title is the wordmark the site actually shows — "rubyco.in", not
  # "RubyCoin", which appeared nowhere on the redesigned pages.
  def full_title(page_title = '')
    page_title.present? ? "#{page_title} | #{MetaHelper::SITE_NAME}" : MetaHelper::SITE_NAME
  end

  # Still read by the old Bootstrap navbar on the Devise screens, the last pages that have
  # not moved to the theme layout. It goes when they do.
  def active_class(link_path)
    current_page?(link_path) ? 'active' : ''
  end

  def switch_locale_to
    I18n.locale == :en ? :uk : :en
  end
end
