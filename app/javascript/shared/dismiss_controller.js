import { Controller } from "@hotwired/stimulus"

// Removes the flash message it sits on (FlashComponent), or itself. With an `after` value the
// message also leaves on its own; hovering or focusing it holds the timer, so a reader who is
// still on it is not cut off.
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

  resume() {
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
