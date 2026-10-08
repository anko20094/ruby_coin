import { Controller } from "@hotwired/stimulus"

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
