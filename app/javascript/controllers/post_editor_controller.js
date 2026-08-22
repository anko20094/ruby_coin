import { Controller } from "@hotwired/stimulus"

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
                    "preview", "lockVersion"]
  static values = { autosaveUrl: String, previewUrl: String, debounce: { type: Number, default: 1200 } }

  connect() {
    this.dirty = new Set()
    this.timer = null
    this.locale = this.localeTargets[0]?.dataset.locale
    this.markTabs()
    this.element.addEventListener("input", this.onInput)
    this.element.addEventListener("trix-change", this.onInput)
  }

  disconnect() {
    clearTimeout(this.timer)
    this.element.removeEventListener("input", this.onInput)
    this.element.removeEventListener("trix-change", this.onInput)
  }

  onInput = (event) => {
    const field = event.target
    if (!field || field.type === "submit") return

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
    this.setState("saving")
    this.previewTarget?.classList.add("is-busy")

    const body = new FormData(this.element)
    body.delete("_method")

    fetch(this.autosaveUrlValue, {
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
        if (data.status === "invalid") return this.setState("invalid", { errors: data.errors.join(", ") })

        this.dirty.clear()
        this.markTabs()
        if (this.hasLockVersionTarget && data.lock_version != null) {
          this.lockVersionTarget.value = data.lock_version
        }
        this.setState("saved", { at: data.at })
        this.reloadPreview()
      })
      .catch(() => {
        this.previewTarget?.classList.remove("is-busy")
        this.setState("invalid", { errors: "network" })
      })
  }

  onConflict() {
    this.setState("conflict")
    if (this.hasConflictTarget) this.conflictTarget.hidden = false
  }

  reloadPreview() {
    if (!this.hasPreviewTarget || !this.hasPreviewUrlValue) return

    const frame = this.previewTarget.querySelector("turbo-frame")
    if (frame) frame.src = this.previewUrlValue
    if (frame) frame.reload()
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
  }

  toggleSideBySide() {
    this.sideBySide = !this.sideBySide
    this.sideBySideTarget?.classList.toggle("is-current", this.sideBySide)
    this.colsTarget?.classList.toggle("is-side-by-side", this.sideBySide)
    this.localeTargets.forEach(group => {
      group.hidden = this.sideBySide ? false : group.dataset.locale !== this.locale
    })
    this.markTabs()
  }

  setWidth(event) {
    const width = event.currentTarget.dataset.width
    this.previewTarget.dataset.width = width
    this.element.querySelectorAll(".mg-preview__width").forEach(button => {
      button.classList.toggle("is-current", button.dataset.width === width)
    })
  }
}
