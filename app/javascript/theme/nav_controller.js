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

    // The panel covers the page, so Tab must not walk out of it into controls nobody can see.
    // A focusin guard rather than a Tab handler: it catches every way focus can move, including
    // Shift+Tab and a screen reader's own navigation.
    this.onFocusIn = (event) => this.keepFocusInside(event)
    document.addEventListener("focusin", this.onFocusIn)
  }

  close() {
    this.open = false
    this.element.classList.remove("is-open")
    this.toggleTarget?.setAttribute("aria-expanded", "false")
    document.body.classList.remove("is-nav-open")

    if (this.onFocusIn) document.removeEventListener("focusin", this.onFocusIn)
    this.onFocusIn = null
  }

  // The toggle counts as inside: while the drawer is open it is the close button.
  keepFocusInside(event) {
    if (!this.open) return
    if (this.drawerTarget.contains(event.target) || this.toggleTarget.contains(event.target)) return

    this.drawerTarget.querySelector("a, button")?.focus()
  }

  escape(event) {
    if (event.key !== "Escape" || !this.open) return
    this.close()
    this.toggleTarget.focus()
  }

  // A tap outside dismisses the menu and does nothing else. Without preventDefault the same
  // tap also followed whatever link sat under it, so closing the menu navigated you away.
  outside(event) {
    if (!this.open || this.element.contains(event.target)) return

    event.preventDefault()
    event.stopPropagation()
    this.close()
    this.toggleTarget?.focus()
  }
}
