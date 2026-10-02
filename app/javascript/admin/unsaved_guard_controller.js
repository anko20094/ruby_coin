import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="unsaved-guard"
//
// Leaving a form with something typed in asks first. A submit, or a save the form made on its
// own, lifts the guard; a form re-rendered after a failed submit starts armed.
//
// A plain form arms it on input/change. The post editor arms it on post-editor:dirty, so the
// autosave controller is the one source of what counts as an edit.
export default class extends Controller {
  static values = { dirty: Boolean }

  connect() {
    window.addEventListener("beforeunload", this.warn)
  }

  disconnect() {
    window.removeEventListener("beforeunload", this.warn)
  }

  // post-editor:dirty carries per-language counts; an empty set after a save arms nothing.
  mark(event) {
    const counts = event?.detail?.counts
    if (counts && Object.keys(counts).length === 0) return

    this.dirtyValue = true
  }

  release() {
    this.dirtyValue = false
  }

  warn = event => {
    if (this.dirtyValue) event.preventDefault()
  }
}
