import { Controller } from "@hotwired/stimulus"

// Click a figure, get the figure. Recruiters retype these numbers into notes and messages by
// hand, so the cell copies "2.14M — users across 2,488 chats" rather than just the digits.
//
// The button and its label are server-rendered, so with JavaScript off the cell is still a
// button that does nothing rather than a broken affordance — see the `is-copyable` class,
// which is only added here.
export default class extends Controller {
  static values = { text: String, done: String }
  static targets = ["flash"]

  connect() {
    if (!navigator.clipboard) return
    this.element.classList.add("is-copyable")
  }

  async copy() {
    if (!navigator.clipboard) return

    try {
      await navigator.clipboard.writeText(this.textValue)
    } catch {
      return
    }

    this.element.classList.add("is-copied")
    if (this.hasFlashTarget) this.flashTarget.textContent = this.doneValue

    clearTimeout(this.timer)
    this.timer = setTimeout(() => {
      this.element.classList.remove("is-copied")
      if (this.hasFlashTarget) this.flashTarget.textContent = ""
    }, 1400)
  }

  disconnect() {
    clearTimeout(this.timer)
  }
}
