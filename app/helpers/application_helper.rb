# frozen_string_literal: true

module ApplicationHelper
  # Replace, not prepend: the admin layout renders FlashComponent as the frame
  # `flash_message`, so the stream swaps the whole region for the new messages.
  def flash_stream
    turbo_stream.replace 'flash_message', FlashComponent.new(flash:, frame_id: 'flash_message')
  end

  # The brand in a document title is the wordmark the site actually shows — "rubyco.in", not
  # "RubyCoin", which appeared nowhere on the redesigned pages.
  def full_title(page_title = '')
    page_title.present? ? "#{page_title} | #{MetaHelper::SITE_NAME}" : MetaHelper::SITE_NAME
  end

  # The name a list item and its page share, so a browser that does cross-document view
  # transitions carries the one into the other (theme/_base.scss). Unique per page by
  # construction: a slug or an id. Nothing for a record that has neither yet (a preview).
  def view_transition_name(kind, key)
    "#{kind}-#{key}" if key.present?
  end

  # On the page a list item opens, where the name is always on. A list carries the name as
  # data-vt-name instead, and theme/view_transitions.js puts it on the one item being opened.
  def view_transition_style(kind, key)
    name = view_transition_name(kind, key)
    "view-transition-name: #{name}" if name
  end
end
