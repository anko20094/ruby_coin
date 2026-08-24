import { Controller } from "@hotwired/stimulus"

// A confirm step that does not depend on Turbo.
//
// The admin's delete affordances were `link_to ... data: { turbo_method: :delete }`, which
// needs Turbo Drive to rewrite the click into a DELETE. Turbo Drive is off on this site by
// decision (redesign_plan.md), so those links navigated as plain GETs to the show URL —
// deleting nothing, and on the post list landing on a 500. They are `button_to` forms now,
// and this is the confirmation that used to be `data-turbo-confirm`.
export default class extends Controller {
  static values = { message: String }

  guard(event) {
    if (!window.confirm(this.messageValue)) event.preventDefault()
  }
}
