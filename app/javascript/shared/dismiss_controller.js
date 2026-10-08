import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { after: Number }

  connect() {
    this.start()
  }

  disconnect() {
    this.stop()
  }

  pause() {
    this.stop()
  }

  // Hover and focus each hold the message; leaving one must not restart the clock while the
  // other still holds it.
  resume() {
    if (this.element.matches(":hover") || this.element.contains(document.activeElement)) return

    this.start()
  }

  close() {
    this.stop()
    const item = this.element.closest(".rc-flash__item") || this.element
    const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    if (reduced || !item.classList.contains("rc-flash__item")) return item.remove()

    item.classList.add("is-leaving")
    item.addEventListener("transitionend", () => item.remove(), { once: true })
    setTimeout(() => item.remove(), 400) // in case the transition never fires
  }

  start() {
    this.stop()
    if (this.afterValue > 0) this.timer = setTimeout(() => this.close(), this.afterValue)
  }

  stop() {
    clearTimeout(this.timer)
  }
}
