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
end
