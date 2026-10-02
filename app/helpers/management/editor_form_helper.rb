# frozen_string_literal: true

# The data attributes that wire an admin form to its Stimulus controllers, kept out of the
# templates so a form tag stays readable.
module Management::EditorFormHelper
  # The post editor: AI translation, autosave + preview (post-editor), tabs and widths
  # (editor-layout) and the leave-page guard. The guard is told about edits by post-editor's
  # own `dirty` event, so one controller decides what counts as a change.
  def post_editor_form_data(post)
    editing = post.persisted?

    {
      controller: 'aitranslation post-editor editor-layout unsaved-guard',
      aitranslation_locale_value: I18n.locale,
      aitranslation_url_value: translate_management_posts_path,
      aitranslation_phrases_value: t('management.posts.editor.translation').to_json,
      # A 409 re-render is a stale form: autosaving it would only conflict again.
      post_editor_autosave_url_value: (autosave_management_post_path(post) if editing && response.status != 409),
      post_editor_preview_url_value: (preview_management_post_path(post) if editing),
      post_editor_locale_value: I18n.locale,
      editor_layout_locale_value: I18n.locale,
      unsaved_guard_dirty_value: unsaved_on_render?(post),
      action: [
        'post-editor:dirty->unsaved-guard#mark',
        'post-editor:dirty->editor-layout#markDirty',
        'editor-layout:locale->post-editor#showLocale',
        'submit->unsaved-guard#release',
        'post-editor:saved->unsaved-guard#release'
      ].join(' ')
    }
  end

  # The case form has no autosave, so the guard listens to the fields directly.
  def case_form_data(kase)
    {
      controller: 'unsaved-guard',
      unsaved_guard_dirty_value: unsaved_on_render?(kase),
      action: 'input->unsaved-guard#mark change->unsaved-guard#mark submit->unsaved-guard#release'
    }
  end

  private

  # A form re-rendered after a refused submit holds what was typed and nothing has saved it.
  def unsaved_on_render?(record) = record.errors.any? || !request.get?
end
