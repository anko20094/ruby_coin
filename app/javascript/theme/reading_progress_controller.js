import { Controller } from "@hotwired/stimulus"

// A 2px ruby bar across the top, showing how much of a long read is behind you.
// Case pages and journal posts only — the long reads; elsewhere it would be noise.
//
// rAF-throttled: the scroll listener does nothing but ask for a frame, and the frame does the
// one width write. Under prefers-reduced-motion the bar still tracks the scroll, it just does
// not ease between values — the bar is information, not decoration.
export default class extends Controller {
  connect() {
    this.frame = null
    this.onScroll = () => {
      if (this.frame) return
      this.frame = requestAnimationFrame(() => {
        this.frame = null
        this.paint()
      })
    }

    window.addEventListener("scroll", this.onScroll, { passive: true })
    window.addEventListener("resize", this.onScroll, { passive: true })
    this.paint()
  }

  disconnect() {
    window.removeEventListener("scroll", this.onScroll)
    window.removeEventListener("resize", this.onScroll)
    if (this.frame) cancelAnimationFrame(this.frame)
  }

  paint() {
    const scrollable = document.documentElement.scrollHeight - window.innerHeight
    const ratio = scrollable > 0 ? Math.min(1, Math.max(0, window.scrollY / scrollable)) : 0
    this.element.style.transform = `scaleX(${ratio})`
    this.element.setAttribute("aria-valuenow", Math.round(ratio * 100))
  }
}
