# frozen_string_literal: true

# The wiring between the admin form and app/javascript/controllers/tinymce_controller.js.
module TinymceHelper
  BASE_URL = '/tinymce'

  # TinyMCE fetches its theme, icons, plugins and skin from BASE_URL at runtime, and public/
  # is not fingerprinted the way app/assets is. Without a suffix an upgrade would be served
  # out of the browser's cache — half the old editor, half the new one. The version is the
  # one bin/copy_tinymce.mjs wrote when it copied the files.
  def tinymce_cache_suffix
    version = Rails.public_path.join('tinymce/VERSION')

    @tinymce_cache_suffix ||= version.exist? ? "?v=#{version.read.strip}" : ''
  end

  # Everything the controller needs, as one data hash. `labels` carries the wording this app adds
  # to TinyMCE, because it builds its dialogs in JavaScript. The editor's own menus stay English:
  # the tinymce package ships no language packs.
  def tinymce_data(profile:, lazy: false, lang: nil, **extra)
    {
      controller: 'tinymce',
      tinymce_profile_value: profile,
      tinymce_lazy_value: lazy,
      tinymce_lang_value: lang,
      tinymce_valid_elements_value: (tinymce_valid_elements if profile == 'case'),
      tinymce_base_url_value: BASE_URL,
      tinymce_cache_suffix_value: tinymce_cache_suffix,
      tinymce_content_css_value: asset_path('theme.css'),
      tinymce_editor_css_value: asset_path('editor_content.css'),
      tinymce_labels_value: tinymce_labels.to_json
    }.merge(extra)
  end

  # What the case editor may produce: exactly what ProseHelper#rich keeps. TinyMCE writes
  # <strong> and <em> and folds <b> and <i> into them.
  def tinymce_valid_elements
    folded = { 'strong' => 'strong/b', 'em' => 'em/i' }

    elements = ProseHelper::RICH_MARKUP.except('b', 'i').map do |tag, attributes|
      element = folded.fetch(tag) { tag }
      attributes.empty? ? element : "#{element}[#{attributes.join('|')}]"
    end

    elements.join(',')
  end

  # The same hash plus what only the post editor uses: the journal-block endpoint and the
  # image upload one.
  def tinymce_post_data
    tinymce_data(profile: 'post',
                 tinymce_blocks_url_value: management_journal_blocks_path,
                 tinymce_upload_url_value: management_editor_images_path)
  end

  private

  def tinymce_labels
    keys = %i[
      blocks insert cancel inline_code language source tone tone_note tone_warn body url
      caption load_error block_error upload_error paragraph heading2 heading3 heading4 preformatted
    ]

    keys.index_with { |key| t("management.editor.tinymce.#{key}") }
        .merge(JournalBlock::KINDS.index_with { |kind| t("management.editor.tinymce.kinds.#{kind}") })
  end
end
