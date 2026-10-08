import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { anchor: { type: String, default: "engineers" } }

  connect() {
    if (window.location.hash === `#${this.anchorValue}`) {
      requestAnimationFrame(() => this.scrollToTrack({ replace: false }))
    }
  }

  jump(event) {
    event.preventDefault()
    this.scrollToTrack({ replace: true })
  }

  scrollToTrack({ replace }) {
    const band = document.getElementById(this.anchorValue)
    if (!band) return

    const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    band.scrollIntoView({ behavior: reduced ? "auto" : "smooth", block: "start" })

    // Scrolling moves the page, not the keyboard. Without this the next Tab carried on from the
    // link that was just used and landed back above the band — the jump undone by one keypress.
    band.focus({ preventScroll: true })

    if (replace) history.replaceState(null, "", `#${this.anchorValue}`)
  }
}
