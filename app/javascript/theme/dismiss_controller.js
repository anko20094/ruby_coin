import { Controller } from "@hotwired/stimulus"

// Removes the element it is attached to. Used by the flash bar's close button.
//
// Deliberately not a timer: the old admin flash deleted itself after six seconds whether or
// not anyone had read it, which is the same as not showing it to a slow reader at all.
export default class extends Controller {
  close() {
    const region = this.element.closest(".rc-flash__item") || this.element
    region.remove()
  }
}
