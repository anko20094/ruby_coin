# frozen_string_literal: true

# What the admin editor is handed, and what it hands back.
module EditorHelper
  # The HTML for one Action Text body, ready for TinyMCE.
  #
  # A stored body keeps a journal block as a bare <action-text-attachment sgid="…">: the block
  # itself lives in its own row and is re-rendered on every page view, which is what lets one
  # partial serve the public page, the preview and the mobile view. An empty element is an
  # invisible hole in a WYSIWYG editor, so each one is filled here with that same partial and
  # marked contenteditable=false.
  #
  # Nothing has to strip the filling out again on save. Action Text discards an attachment's
  # children and re-renders from the sgid — verified, and covered by
  # spec/helpers/editor_helper_spec.rb, because the whole approach rests on it.
  def editor_html(rich_text)
    return '' if rich_text.nil?

    filled = rich_text.body.render_attachments do |attachment|
      node = attachment.node
      node['contenteditable'] = 'false'
      node.inner_html = attachment_preview(attachment)
      node.to_html
    end

    filled.to_html
  end

  private

  def attachment_preview(attachment)
    attachable = attachment.attachable

    return render(attachable) if attachable.is_a?(JournalBlock)

    # An image or a file: Action Text's own partial already knows how to draw it.
    attachment.to_html
  rescue ActionView::MissingTemplate, ActiveSupport::MessageVerifier::InvalidSignature
    ''
  end
end
