import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    section: { type: String, default: ".hm-hero" },
    until: { type: String, default: ".rc-footer" },
    ratio: { type: Number, default: 0.15 },
    offset: { type: Number, default: 120 },
  }

  connect() {
    const hero = document.querySelector(this.sectionValue)
    if (!hero || !("IntersectionObserver" in window)) return

    this.element.hidden = false
    this.heroVisible = true
    this.footerVisible = false

    this.observer = new IntersectionObserver(
      ([entry]) => {
        this.heroVisible = entry.intersectionRatio > this.ratioValue
        this.render()
      },
      { threshold: [0, this.ratioValue, 0.5, 1] },
    )
    this.observer.observe(hero)

    // It sits bottom-right, which is where the footer keeps its contact links — at the foot of
    // the page an 84px button was covering all three of them. A back-to-top affordance has
    // nothing to offer once you have arrived at the bottom anyway.
    const footer = document.querySelector(this.untilValue)
    if (footer) {
      this.footerObserver = new IntersectionObserver(
        ([entry]) => {
          this.footerVisible = entry.isIntersecting
          this.render()
        },
        { threshold: 0 },
      )
      this.footerObserver.observe(footer)
    }

    this.onScroll = () => this.render()
    window.addEventListener("scroll", this.onScroll, { passive: true })
    this.render()
  }

  disconnect() {
    this.observer?.disconnect()
    this.footerObserver?.disconnect()
    if (this.onScroll) window.removeEventListener("scroll", this.onScroll)
  }

  render() {
    const past = !this.heroVisible && !this.footerVisible && window.scrollY > this.offsetValue
    this.element.classList.toggle("is-visible", past)
  }

  toTop() {
    const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    window.scrollTo({ top: 0, behavior: reduced ? "auto" : "smooth" })
  }
}
