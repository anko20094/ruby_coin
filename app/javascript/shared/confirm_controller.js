import { Controller } from "@hotwired/stimulus"

// A confirm step that does not depend on Turbo. Turbo Drive is off on this site, so
// `data-turbo-confirm` never fires; deletes are `button_to` forms guarded by this instead.
export default class extends Controller {
  static values = { message: String }

  guard(event) {
    if (!window.confirm(this.messageValue)) event.preventDefault()
  }
}
