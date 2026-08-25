import { Controller } from "@hotwired/stimulus"
import { REVEAL_EVENT } from "./tinymce_controller"

// Connects to data-controller="post-editor"
//
// Autosave, the save-state indicator, per-language dirty counts, the language tabs and the
// conflict banner. Handoff §8.
//
// Three things worth knowing:
//
//   1. Hidden language groups are only display:none — their fields still post. Switching tabs
//      never loses what is typed in the other language.
//   2. The server answers autosave with a status, and "invalid" is a real one: a post has to
//      have a title, a lede and a body in the locale being edited before it can be saved at
//      all. The indicator says what is missing instead of pretending the save worked.
//   3. Conflicts are detected by the real lock_version, not by a timestamp guess. On a
//      conflict nothing has been written, so the banner offers to reload theirs.
export default class extends Controller {
  static targets = ["state", "stateText", "conflict", "locale", "tab", "sideBySide", "cols",
                    "preview", "lockVersion", "previewLocale", "openLink"]
  static values = { autosaveUrl: String, previewUrl: String, debounce: { type: Number, default: 1200 } }

  connect() {
    this.dirty = new Set()
    this.timer = null
    // The autosave currently in the air, if there is one, and whether a real submit is on its
    // way. Between them they are what stops the two racing — see onSubmit.
    this.saving = null
    this.submitting = false
    this.locale = this.localeTargets[0]?.dataset.locale
    this.markTabs()
    this.markPreviewLocale()
    this.element.addEventListener("input", this.onInput)
    this.element.addEventListener("submit", this.onSubmit)
  }

  disconnect() {
    clearTimeout(this.timer)
    this.element.removeEventListener("input", this.onInput)
    this.element.removeEventListener("submit", this.onSubmit)
  }

  // Pressing Save while an autosave is in the air is how this screen used to 500.
  //
  // The autosave lands first and raises lock_version. The submit is already built, holding the
  // number from before it, and Active Record calls that a stale object — so an editor who
  // typed and then reached for Save inside the debounce window got a backtrace with their
  // whole article in it.
  //
  // Two things, in order: the pending autosave is cancelled, because the submit is about to
  // write everything anyway. And if one is already in flight, the submit waits for it and goes
  // afterwards, by which time syncLockVersion has taken the version the server reports.
  onSubmit = (event) => {
    clearTimeout(this.timer)

    if (this.submitting || !this.saving) {
      this.submitting = true
      return
    }

    event.preventDefault()
    this.submitting = true
    this.setState("saving")
    this.saving.finally(() => this.element.requestSubmit())
  }

  onInput = (event) => {
    const field = event.target
    if (!field || field.type === "submit" || this.submitting) return

    this.dirty.add(this.fieldKey(field))
    this.setState("dirty")
    this.markTabs()

    if (!this.hasAutosaveUrlValue || this.autosaveUrlValue === "") return

    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.save(), this.debounceValue)
  }

  // Which language a field belongs to, so the tab counts mean something. Fields outside a
  // language group (slug, tags, cover) are counted under "meta".
  fieldKey(field) {
    const group = field.closest("[data-post-editor-target='locale']")
    return `${group ? group.dataset.locale : "meta"}:${field.name || field.id}`
  }

  save() {
    // A submit is on its way and will write everything; one more PATCH would only move
    // lock_version out from under it.
    if (this.submitting) return

    this.setState("saving")
    this.previewTarget?.classList.add("is-busy")

    const body = new FormData(this.element)
    body.delete("_method")

    this.saving = fetch(this.autosaveUrlValue, {
      method: "PATCH",
      headers: {
        "X-CSRF-Token": document.querySelector("meta[name=csrf-token]")?.getAttribute("content"),
        "Accept": "application/json",
      },
      body,
    })
      .then(response => response.json().then(data => ({ status: response.status, data })))
      .then(({ status, data }) => {
        this.previewTarget?.classList.remove("is-busy")

        if (status === 409) return this.onConflict(data)

        // The version comes back on every answer, success or not, and the form takes it
        // whichever way the save went. Skipping it on "invalid" is what used to leave the
        // editor a version behind and turn the next keystroke into a phantom conflict.
        this.syncLockVersion(data)

        if (data.status === "invalid") return this.setState("invalid", { errors: data.errors.join(", ") })

        this.dirty.clear()
        this.markTabs()
        this.setState("saved", { at: data.at })
        this.reloadPreview()
      })
      .catch(() => {
        this.previewTarget?.classList.remove("is-busy")
        this.setState("invalid", { errors: "network" })
      })
      .finally(() => { this.saving = null })

    return this.saving
  }

  syncLockVersion(data) {
    if (this.hasLockVersionTarget && data.lock_version != null) {
      this.lockVersionTarget.value = data.lock_version
    }
  }

  onConflict() {
    this.setState("conflict")
    if (this.hasConflictTarget) this.conflictTarget.hidden = false
  }

  // The preview is of one language, and it has to be the one the tab is on. It used to render
  // in whatever language the admin's own chrome was in — so writing Ukrainian showed an
  // English preview, with nothing on the pane saying which was which.
  reloadPreview() {
    if (!this.hasPreviewTarget || !this.hasPreviewUrlValue) return

    const frame = this.previewTarget.querySelector("turbo-frame")
    if (!frame) return

    const url = new URL(this.previewUrlValue, window.location.origin)
    url.searchParams.set("preview_locale", this.locale)
    frame.src = url.pathname + url.search
    frame.reload()
  }

  // The badge on the pane, and the link out to the real page, both follow the tab.
  markPreviewLocale() {
    if (this.hasPreviewLocaleTarget) this.previewLocaleTarget.textContent = this.locale
    this.openLinkTargets.forEach(link => { link.hidden = link.dataset.locale !== this.locale })
  }

  setState(name, interpolations = {}) {
    if (!this.hasStateTarget) return

    this.stateTarget.dataset.state = name
    this.stateTextTarget.textContent = this.phrase(name, interpolations)
  }

  // The wording lives in the markup so it stays translated: each state's text is read from a
  // data attribute the server rendered.
  phrase(name, interpolations) {
    const template = this.stateTarget.dataset[`phrase${name[0].toUpperCase()}${name.slice(1)}`] || name
    return Object.entries(interpolations)
      .reduce((text, [key, value]) => text.replace(`%{${key}}`, value), template)
  }

  markTabs() {
    const counts = {}
    this.dirty.forEach(key => {
      const locale = key.split(":")[0]
      counts[locale] = (counts[locale] || 0) + 1
    })

    this.tabTargets.forEach(tab => {
      const locale = tab.dataset.locale
      tab.classList.toggle("is-current", locale === this.locale && !this.sideBySide)
      const badge = tab.querySelector(".mg-tab__dirty")
      if (badge) badge.textContent = counts[locale] ? String(counts[locale]) : ""
    })
  }

  pickLocale(event) {
    this.sideBySide = false
    this.locale = event.currentTarget.dataset.locale
    this.sideBySideTarget?.classList.remove("is-current")
    this.colsTarget?.classList.remove("is-side-by-side")
    this.localeTargets.forEach(group => { group.hidden = group.dataset.locale !== this.locale })
    this.markTabs()
    this.markPreviewLocale()
    this.reloadPreview()
    this.announceReveal()
  }

  toggleSideBySide() {
    this.sideBySide = !this.sideBySide
    this.sideBySideTarget?.classList.toggle("is-current", this.sideBySide)
    this.colsTarget?.classList.toggle("is-side-by-side", this.sideBySide)
    this.localeTargets.forEach(group => {
      group.hidden = this.sideBySide ? false : group.dataset.locale !== this.locale
    })
    this.markTabs()
    this.announceReveal()
  }

  // The editors grow with their content, and one built inside a hidden tab had nothing to
  // measure and settled at its floor. Switching tabs is the moment it can see the page.
  announceReveal() {
    document.dispatchEvent(new CustomEvent(REVEAL_EVENT))
  }

  setWidth(event) {
    const width = event.currentTarget.dataset.width
    this.previewTarget.dataset.width = width
    this.element.querySelectorAll(".mg-preview__width").forEach(button => {
      button.classList.toggle("is-current", button.dataset.width === width)
    })
  }
}
