import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="floating-ruby"
//
// Shows a small ruby once the hero one has scrolled out of view, and scrolls back to it on
// click. Under prefers-reduced-motion the button still works — it just appears without the
// fade and jumps instead of gliding.
export default class extends Controller {
  static values = { threshold: { type: Number, default: 0.25 } }

  connect() {
    this.hero = document.querySelector(".rc-gem--hero")
    if (!this.hero || !("IntersectionObserver" in window)) return

    this.element.hidden = false
    this.observer = new IntersectionObserver(
      ([entry]) => this.element.classList.toggle("is-visible", entry.intersectionRatio < this.thresholdValue),
      { threshold: [0, this.thresholdValue, 1] },
    )
    this.observer.observe(this.hero)
  }

  disconnect() {
    this.observer?.disconnect()
  }

  toTop() {
    const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    window.scrollTo({ top: 0, behavior: reduced ? "auto" : "smooth" })
  }
}
