import { Controller } from "@hotwired/stimulus"

// The two-track case page reads in sequence, and the whole point of that shape is that
// /work/dna#engineers is a sendable link: one URL for the recruiter, another for the CTO.
//
// This does the two halves of that. Clicking "skip to the engineering" scrolls to the band and
// writes #engineers into the address bar without adding a history entry, so the link the
// reader copies is the one they are looking at. And an arriving #engineers is honoured on
// load, which the browser does not do reliably when the anchor is below lazily-sized content.
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
