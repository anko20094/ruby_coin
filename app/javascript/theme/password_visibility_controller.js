import { Controller } from "@hotwired/stimulus"

// The reveal button beside a password field. It says what it will do next (aria-label) and
// what state it is in (aria-pressed), so the change on screen is not only a visual one.
export default class extends Controller {
  static targets = ["input", "toggle"]
  static values = { showLabel: String, hideLabel: String }

  toggleVisibility(event) {
    event.preventDefault()

    const revealed = this.inputTarget.type === "password"
    this.inputTarget.type = revealed ? "text" : "password"

    const button = this.hasToggleTarget ? this.toggleTarget : event.currentTarget
    button.setAttribute("aria-pressed", String(revealed))
    button.classList.toggle("is-active", revealed)
    const label = revealed ? this.hideLabelValue : this.showLabelValue
    if (label) {
      button.setAttribute("aria-label", label)
      button.setAttribute("title", label)
    }
  }
}
