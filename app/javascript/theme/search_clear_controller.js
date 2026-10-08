import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  // The search field's own clear button, in place of the browser's: shown only while there is
  // something to clear. Clearing goes through an input event, so live search hears it as the
  // reader emptying the field and puts the list back.
  static targets = ["input", "button"];

  connect() {
    this.element.classList.add("is-clearable");
    this.sync();
  }

  disconnect() {
    this.element.classList.remove("is-clearable");
  }

  sync() {
    this.buttonTarget.hidden = this.inputTarget.value === "";
  }

  clear() {
    this.inputTarget.value = "";
    this.inputTarget.dispatchEvent(new Event("input", { bubbles: true }));
    this.inputTarget.focus();
  }
}
