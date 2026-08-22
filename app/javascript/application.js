// Entry point for the build script in your package.json
import './controllers'
import "@hotwired/turbo-rails"
Turbo.session.drive = false
import 'bootstrap/js/dist/dropdown'
import 'bootstrap/js/dist/modal'
import 'bootstrap/js/dist/collapse'
import { BootstrapToggle } from 'bootstrap5-toggle'
import * as ActiveStorage from "@rails/activestorage"
// Trix is the admin body editor; only this bundle loads it.
import "trix"
import "@rails/actiontext"

const initBootstrapToggles = () => {
  document
    .querySelectorAll("input[type='checkbox'][data-toggle='toggle']")
    .forEach((element) => {
      if (!element.bsToggle) {
        // bootstrap5-toggle stores an instance on element.bsToggle
        new BootstrapToggle(element)
      }
    })
}

document.addEventListener('DOMContentLoaded', initBootstrapToggles)
document.addEventListener('turbo:load', initBootstrapToggles)

ActiveStorage.start()