import { Controller } from "@hotwired/stimulus"

// The reveal button on the sign-in and password screens.
//
// It lived in the admin bundle while those screens were on the old layout. They are on the
// theme now, so it is here — and it reports its state, which a button that changes what is on
// screen has to do.
export default class extends Controller {
  static targets = ["input"]

  toggleVisibility(event) {
    event.preventDefault()

    const input = this.inputTarget
    const revealed = input.type === "text"

    input.type = revealed ? "password" : "text"
    event.currentTarget.setAttribute("aria-pressed", String(!revealed))
    event.currentTarget.classList.toggle("is-active", !revealed)
  }
}
