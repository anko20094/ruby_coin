// /management. Everything the admin needs and nothing the public site does.
//
// This was two entries: application.js for the old Bootstrap layout, and this. The Devise
// screens were the last pages on that layout and have moved to the theme, so there is nothing
// left for a second bundle to serve.
import { application } from "./controllers/application"

// Turbo earns its place here and nowhere else: the tag screen answers in frames and streams,
// and the editor reloads its preview into one. Drive stays off, by decision.
import "@hotwired/turbo-rails"
Turbo.session.drive = false

import FlashController from "./controllers/flash_controller"
application.register("flash", FlashController)

import AitranslationController from "./controllers/aitranslation_controller"
application.register("aitranslation", AitranslationController)

import ConfirmController from "./controllers/confirm_controller"
application.register("confirm", ConfirmController)

import PostEditorController from "./controllers/post_editor_controller"
application.register("post-editor", PostEditorController)

import SlashMenuController from "./controllers/slash_menu_controller"
application.register("slash-menu", SlashMenuController)

import TomselectController from "./controllers/tomselect_controller"
application.register("tomselect", TomselectController)

import "bootstrap/js/dist/dropdown"
import "bootstrap/js/dist/collapse"
import "bootstrap/js/dist/modal"
import { BootstrapToggle } from "bootstrap5-toggle"
import * as ActiveStorage from "@rails/activestorage"
// Trix is the admin body editor; only this bundle loads it.
import "trix"
import "@rails/actiontext"

const initBootstrapToggles = () => {
  document
    .querySelectorAll("input[type='checkbox'][data-toggle='toggle']")
    .forEach((element) => {
      // bootstrap5-toggle stores an instance on element.bsToggle
      if (!element.bsToggle) new BootstrapToggle(element)
    })
}

document.addEventListener("DOMContentLoaded", initBootstrapToggles)
document.addEventListener("turbo:load", initBootstrapToggles)

ActiveStorage.start()
