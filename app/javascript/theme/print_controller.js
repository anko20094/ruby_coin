import { Controller } from "@hotwired/stimulus"

// "save as pdf" on /cv. There is no PDF to download and there does not need to be one: the
// print stylesheet (theme/_print.scss) is what the browser saves.
export default class extends Controller {
  now() {
    window.print()
  }
}
