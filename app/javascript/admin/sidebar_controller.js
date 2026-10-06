import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="sidebar"
//
// Collapses the /management sidebar to a rail. The editor is a three-column screen on a pane
// that already gave 232px to navigation you are not using while you write.
//
// The state is a cookie rather than localStorage, and that is the whole design. The admin
// bundle is deferred and the admin's CSP has no inline script, so a class stamped by
// JavaScript would arrive after first paint and the sidebar would flash open on every single
// page load. A cookie is on the request, so the layout stamps the class server-side and the
// first paint is already right.
const COOKIE = "mg_sidebar"
const YEAR = 60 * 60 * 24 * 365

export default class extends Controller {
  static targets = ["toggle"]
  static values = { shellSelector: { type: String, default: ".mg-shell" } }

  toggle() {
    const shell = document.querySelector(this.shellSelectorValue)
    const collapsed = shell.classList.toggle("is-sidebar-collapsed")

    document.cookie = `${COOKIE}=${collapsed ? "collapsed" : "open"};path=/;max-age=${YEAR};samesite=lax`
    this.announce(collapsed)
  }

  announce(collapsed) {
    this.toggleTargets.forEach(button => {
      button.setAttribute("aria-expanded", String(!collapsed))
      const label = button.dataset[collapsed ? "labelExpand" : "labelCollapse"]
      if (label) {
        button.setAttribute("aria-label", label)
        button.setAttribute("title", label)
      }
    })
  }
}
