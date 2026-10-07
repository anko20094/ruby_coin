import { Controller } from "@hotwired/stimulus"

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
