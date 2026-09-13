import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="floating-ruby"
//
// Shows a small ruby once the hero has scrolled away, and scrolls back to it on click. Under
// prefers-reduced-motion the button still works — it just appears without the fade and jumps
// instead of gliding.
//
// Two conditions, not one, and the observed element is the hero SECTION rather than the gem
// inside it: in one column the gem starts below the fold, so a gem-based observer fires on
// first paint and the reader lands on a back-to-top button pointing where they already are.
// The scroll gate is the belt to those braces — on a viewport short enough to hide the whole
// hero, the observer alone is not enough.
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
