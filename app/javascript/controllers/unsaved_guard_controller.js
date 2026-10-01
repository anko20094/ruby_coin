import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="unsaved-guard"
//
// Leaving a form with something typed in asks first. A submit, or a save the form made on its
// own, lifts the guard; a form re-rendered after a failed submit starts armed.
//
//   data-action="input->unsaved-guard#mark change->unsaved-guard#mark
//                submit->unsaved-guard#release post-editor:saved->unsaved-guard#release"
export default class extends Controller {
  static values = { dirty: Boolean }

  connect() {
    window.addEventListener("beforeunload", this.warn)
  }

  disconnect() {
    window.removeEventListener("beforeunload", this.warn)
  }

  mark() {
    this.dirtyValue = true
  }

  release() {
    this.dirtyValue = false
  }

  warn = event => {
    if (this.dirtyValue) event.preventDefault()
  }
}
