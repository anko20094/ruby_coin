import { Controller } from "@hotwired/stimulus"

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
