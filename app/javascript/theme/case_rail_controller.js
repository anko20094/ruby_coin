import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  // The case page's side rail, on wide screens. Two jobs, both optional extras over a list of
  // plain anchors: show the figures once the strip that carries them has scrolled away, and mark
  // which section the reader is in. Without IntersectionObserver the rail is just the list.
  static targets = ["metrics", "link"]

  connect() {
    if (!("IntersectionObserver" in window)) return

    this.watchStrip()
    this.watchSections()
  }

  disconnect() {
    this.stripObserver?.disconnect()
    this.sectionObserver?.disconnect()
  }

  watchStrip() {
    const strip = document.querySelector(".wk-case__strip")
    if (!strip || !this.hasMetricsTarget) return

    this.stripObserver = new IntersectionObserver(([entry]) => {
      this.metricsTarget.hidden = entry.isIntersecting
    })
    this.stripObserver.observe(strip)
  }

  // A section counts as current while it crosses a line a third of the way down the window —
  // where the eye is, rather than the top edge the nav covers.
  watchSections() {
    const sections = this.linkTargets
      .map((link) => document.getElementById(link.hash.slice(1)))
      .filter(Boolean)
    if (sections.length === 0) return

    this.sectionObserver = new IntersectionObserver((entries) => {
      entries.filter((entry) => entry.isIntersecting).forEach((entry) => this.mark(entry.target.id))
    }, { rootMargin: "-33% 0px -66% 0px" })
    sections.forEach((section) => this.sectionObserver.observe(section))
  }

  mark(id) {
    this.linkTargets.forEach((link) => {
      const current = link.hash === `#${id}`
      link.classList.toggle("is-active", current)
      if (current) {
        link.setAttribute("aria-current", "location")
      } else {
        link.removeAttribute("aria-current")
      }
    })
  }
}
