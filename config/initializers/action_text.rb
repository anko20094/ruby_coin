# frozen_string_literal: true

# What an article body is allowed to contain.
#
# Action Text sanitises on render, using Rails' default safe list — which stops at <p>, <ul>,
# <blockquote> and <img>. That was enough while the editor was Trix, because Trix cannot
# produce anything else. The editor is TinyMCE again, and a toolbar that offers a table, an
# anchor or a centred paragraph and then loses it on save is worse than not offering it: the
# author sees the change in the editor, saves, and the page comes back without it.
#
# So the list is widened to exactly what the toolbar can make, and no further.
#
# `style` is deliberately not on it. It is the one attribute in a sanitiser's allow list that
# carries real risk, and the site's typography is a design decision rather than a per-post one.
# TinyMCE is configured to write alignment as a class instead (see the `formats` block in
# app/javascript/admin/tinymce/profiles.js), and those classes are styled in
# app/assets/stylesheets/pages/_journal_post.scss.
Rails.application.config.after_initialize do
  ActionText::ContentHelper.allowed_tags = Rails::HTML5::SafeListSanitizer.allowed_tags + %w[
    table thead tbody tfoot tr td th caption col colgroup
    figure figcaption
    s u strike
  ]

  ActionText::ContentHelper.allowed_attributes = Rails::HTML5::SafeListSanitizer.allowed_attributes + %w[
    colspan rowspan scope span
    id dir start reversed
    target rel loading
  ]
end
