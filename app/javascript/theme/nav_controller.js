import { Controller } from "@hotwired/stimulus"

// The mobile drawer. Wide screens never reach any of this — the drawer is the nav row there,
// laid out by CSS — so the controller only has to be correct below the breakpoint.
//
// Correct means: the button reports its state, Escape closes, a click outside closes, focus
// moves into the drawer on open and back to the button on close, and the page behind does not
// scroll while it is open.
export default class extends Controller {
  static targets = ["toggle", "drawer"]

  connect() {
    this.close()
  }

  disconnect() {
    document.body.classList.remove("is-nav-open")
  }

  toggle(event) {
    event.stopPropagation()
    this.open ? this.close() : this.show()
  }

  show() {
    this.open = true
    this.element.classList.add("is-open")
    this.toggleTarget.setAttribute("aria-expanded", "true")
    document.body.classList.add("is-nav-open")
    this.drawerTarget.querySelector("a")?.focus()
  }

  close() {
    this.open = false
    this.element.classList.remove("is-open")
    this.toggleTarget?.setAttribute("aria-expanded", "false")
    document.body.classList.remove("is-nav-open")
  }

  escape(event) {
    if (event.key !== "Escape" || !this.open) return
    this.close()
    this.toggleTarget.focus()
  }

  outside(event) {
    if (!this.open || this.element.contains(event.target)) return
    this.close()
  }
}
