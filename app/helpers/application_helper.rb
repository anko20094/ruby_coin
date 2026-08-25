# frozen_string_literal: true

module ApplicationHelper
  # Pagy 43+: provide compatibility wrapper for existing views
  def pagy_bootstrap_nav(pagy, classes: 'pagination', **)
    pagy.series_nav(:bootstrap, classes:, **).html_safe # rubocop:disable Rails/OutputSafety
  end

  # Replace, not prepend, and aimed at the frame that actually exists. This used to target
  # id="flash", which is rendered nowhere in the app — Turbo drops a stream whose target is
  # missing, silently, so every tag create/update/destroy and every post destroy acknowledged
  # nothing. `shared/flash` *is* the frame, so it replaces itself rather than nesting.
  def flash_stream
    turbo_stream.replace 'flash_message', partial: 'shared/flash'
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
