import { Controller } from "@hotwired/stimulus"
import { REVEAL_EVENT } from "./tinymce/loader"

export default class extends Controller {
  static targets = ["locale", "tab", "sideBySide", "cols", "preview", "previewLocale", "openLink", "width"]
  static values = { locale: String }

  connect() {
    this.sideBySide = false
    if (!this.localeValue) this.localeValue = this.localeTargets[0]?.dataset.locale
    this.markTabs()
    this.markPreviewLocale()
  }

  pickLocale(event) {
    this.sideBySide = false
    this.localeValue = event.currentTarget.dataset.locale
    if (this.hasSideBySideTarget) this.press(this.sideBySideTarget, false)
    if (this.hasColsTarget) this.colsTarget.classList.remove("is-side-by-side")
    this.localeTargets.forEach(group => { group.hidden = group.dataset.locale !== this.localeValue })
    this.markTabs()
    this.markPreviewLocale()
    this.dispatch("locale", { detail: { locale: this.localeValue } })
    this.announceReveal()
  }

  toggleSideBySide() {
    this.sideBySide = !this.sideBySide
    if (this.hasSideBySideTarget) this.press(this.sideBySideTarget, this.sideBySide)
    if (this.hasColsTarget) this.colsTarget.classList.toggle("is-side-by-side", this.sideBySide)
    this.localeTargets.forEach(group => {
      group.hidden = this.sideBySide ? false : group.dataset.locale !== this.localeValue
    })
    this.markTabs()
    this.announceReveal()
  }

  setWidth(event) {
    const width = event.currentTarget.dataset.width
    if (this.hasPreviewTarget) this.previewTarget.dataset.width = width
    this.widthTargets.forEach(button => this.press(button, button.dataset.width === width))
  }

  // post-editor:dirty — { counts: { uk: 2, meta: 1 } }
  markDirty(event) {
    const counts = event.detail?.counts || {}
    this.tabTargets.forEach(tab => {
      const badge = tab.querySelector(".mg-tab__dirty")
      const count = counts[tab.dataset.locale]
      if (badge) badge.textContent = count ? String(count) : ""
    })
  }

  markTabs() {
    this.tabTargets.forEach(tab => this.press(tab, tab.dataset.locale === this.localeValue && !this.sideBySide))
  }

  // The badge on the pane, and the link out to the real page, both follow the tab.
  markPreviewLocale() {
    if (this.hasPreviewLocaleTarget) this.previewLocaleTarget.textContent = this.localeValue
    this.openLinkTargets.forEach(link => { link.hidden = link.dataset.locale !== this.localeValue })
  }

  // An editor built inside a hidden tab measured itself at zero; this is when it can see the page.
  announceReveal() {
    document.dispatchEvent(new CustomEvent(REVEAL_EVENT))
  }

  // These buttons are choices, so the choice made is said in markup and not only painted.
  press(button, pressed) {
    button.classList.toggle("is-current", pressed)
    button.setAttribute("aria-pressed", String(pressed))
  }
}
