// /management. Everything the admin needs and nothing the public site does.
//
// admin/  — controllers only the admin screens use.
// shared/ — controllers both bundles register (theme.js takes the same files).
import { Application } from "@hotwired/stimulus"

// Turbo earns its place here and nowhere else: the tag screen answers in frames and streams,
// and the editor reloads its preview into one. Drive stays off, by decision.
import "@hotwired/turbo-rails"
Turbo.session.drive = false

import ConfirmController from "./shared/confirm_controller"
import DismissController from "./shared/dismiss_controller"
import AitranslationController from "./admin/aitranslation_controller"
import PostEditorController from "./admin/post_editor_controller"
import EditorLayoutController from "./admin/editor_layout_controller"
import TomselectController from "./admin/tomselect_controller"
import TinymceController from "./admin/tinymce_controller"
import StructureRowsController from "./admin/structure_rows_controller"
import UnsavedGuardController from "./admin/unsaved_guard_controller"
import SidebarController from "./admin/sidebar_controller"

const application = Application.start()
application.register("confirm", ConfirmController)
application.register("dismiss", DismissController)
application.register("aitranslation", AitranslationController)
application.register("post-editor", PostEditorController)
application.register("editor-layout", EditorLayoutController)
application.register("tomselect", TomselectController)
application.register("tinymce", TinymceController)
application.register("structure-rows", StructureRowsController)
application.register("unsaved-guard", UnsavedGuardController)
application.register("sidebar", SidebarController)

// No editor import: TinyMCE is self-hosted under public/tinymce and loads itself the first
// time a screen has a textarea asking for it, so list pages never carry 500 KB of editor.
