import { Controller } from "@hotwired/stimulus"

// Click a figure, get the figure. Recruiters retype these numbers into notes and messages by
// hand, so the cell copies "<value> — <label>" rather than just the digits.
//
// The button and its label are server-rendered, so with JavaScript off the cell is still a
// button that does nothing rather than a broken affordance — see the `is-copyable` class,
// which is only added here.
export default class extends Controller {
  static values = { text: String, done: String }
  static targets = ["flash"]

  connect() {
    this.element.classList.add("is-copyable")
  }

  async copy() {
    try {
      await this.write(this.textValue)
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

  // navigator.clipboard exists only in a secure context, and the site is served over plain
  // HTTP, so the old selection-and-command route is what has to work there.
  async write(text) {
    if (navigator.clipboard) return navigator.clipboard.writeText(text)

    const field = document.createElement("textarea")
    field.value = text
    field.setAttribute("readonly", "")
    Object.assign(field.style, { position: "fixed", top: "0", left: "0", opacity: "0" })
    document.body.append(field)
    field.select()
    const copied = document.execCommand("copy")
    field.remove()
    this.element.focus({ preventScroll: true })

    if (!copied) throw new Error("copy was refused")
  }
}
