import { Controller } from "@hotwired/stimulus"
import { sendForm } from "../lib/http"

// Connects to data-controller="post-editor"
//
// Autosave, the save-state indicator, the preview and the conflict banner. The one place that
// decides what counts as an unsaved edit: it dispatches `post-editor:dirty` with per-language
// counts (editor-layout draws them on the tabs, unsaved-guard arms itself) and
// `post-editor:saved` once everything typed is written.
//
//   1. The server answers autosave with a status, and "invalid" is a real one: a post needs a
//      title, a lede and a body in the locale being edited. The indicator says what is missing.
//   2. Conflicts are detected by the real lock_version. On a conflict nothing has been written,
//      so the banner offers to reload theirs.
export default class extends Controller {
  static targets = ["state", "stateText", "conflict", "preview", "lockVersion"]
  static values = {
    autosaveUrl: String,
    previewUrl: String,
    locale: String,
    debounce: { type: Number, default: 1200 },
  }

  connect() {
    this.dirty = new Set()
    this.timer = null
    // The autosave currently in the air, if there is one, and whether a real submit is on its
    // way. Between them they are what stops the two racing — see onSubmit.
    this.saving = null
    this.queued = false
    this.submitting = false
    this.edits = 0
    this.element.addEventListener("input", this.onInput)
    this.element.addEventListener("submit", this.onSubmit)
    window.addEventListener("pageshow", this.onPageShow)
  }

  disconnect() {
    clearTimeout(this.timer)
    this.element.removeEventListener("input", this.onInput)
    this.element.removeEventListener("submit", this.onSubmit)
    window.removeEventListener("pageshow", this.onPageShow)
  }

  // Back after Save restores this page from the back/forward cache with its script state as it
  // was: `submitting` still set, so nothing autosaves, and lock_version a save behind.
  onPageShow = (event) => {
    if (event.persisted) window.location.reload()
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

    this.edits += 1
    this.dirty.add(this.fieldKey(field))
    this.setState("dirty")
    this.announceDirty()

    // Autosave never writes the slug, so typing in it has nothing to save until the form is.
    if (field === this.slugField) return

    if (!this.hasAutosaveUrlValue || this.autosaveUrlValue === "") return

    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.save(), this.debounceValue)
  }

  get slugField() {
    return this.element.querySelector("[name='post[slug]']")
  }

  // A slug typed and not yet submitted: the server's answer to an autosave does not cover it.
  get slugPending() {
    const field = this.slugField
    return Boolean(field) && field.value !== field.defaultValue
  }

  // Which language a field belongs to, so the tab counts mean something. Fields outside a
  // language group (slug, tags, cover) are counted under "meta".
  fieldKey(field) {
    const group = field.closest("[data-locale]")
    return `${group ? group.dataset.locale : "meta"}:${field.name || field.id}`
  }

  announceDirty() {
    const counts = {}
    this.dirty.forEach(key => {
      const locale = key.split(":")[0]
      counts[locale] = (counts[locale] || 0) + 1
    })
    this.dispatch("dirty", { detail: { counts } })
  }

  save() {
    // A submit is on its way and will write everything; one more PATCH would only move
    // lock_version out from under it.
    if (this.submitting) return

    // One in the air at a time: the next is built from the version this one reports.
    if (this.saving) {
      this.queued = true
      return this.saving
    }

    this.setState("saving")
    this.previewTarget?.classList.add("is-busy")

    const body = new FormData(this.element)
    body.delete("_method")
    const uploads = this.selectedFiles()
    const edits = this.edits

    this.saving = sendForm(this.autosaveUrlValue, body, { method: "PATCH" })
      .then(response => response.json().then(data => ({ response, data })))
      .then(({ response, data }) => {
        this.previewTarget?.classList.remove("is-busy")

        if (response.status === 409) return this.onConflict()
        if (data.status === "invalid") return this.setState("invalid", { errors: data.errors.join(", ") })
        if (!response.ok || data.status !== "saved") return this.setState("failed")

        this.syncLockVersion(data)
        this.forgetUploaded(uploads)
        this.dirty.clear()
        const slugPending = this.slugPending
        if (slugPending) this.dirty.add(this.fieldKey(this.slugField))
        this.announceDirty()
        if (this.hasConflictTarget) this.conflictTarget.hidden = true
        this.setState(slugPending ? "dirty" : "saved", { at: data.at })
        this.reloadPreview()
        // Typing since the snapshot is not in what was saved; the autosave it armed will say so.
        if (this.edits === edits && !slugPending) this.dispatch("saved")
      })
      .catch(() => {
        this.previewTarget?.classList.remove("is-busy")
        this.setState("failed")
      })
      .finally(() => {
        this.saving = null
        if (this.queued) {
          this.queued = false
          this.save()
        }
      })

    return this.saving
  }

  // Only a save that wrote hands out a version, so only a "saved" answer is taken: a refused one
  // wrote nothing, and the version the form holds is still the one its content was loaded at.
  syncLockVersion(data) {
    if (this.hasLockVersionTarget && data.lock_version != null) {
      this.lockVersionTarget.value = data.lock_version
    }
  }

  // The cover is in the form for as long as the file is selected, so without this every pause
  // would upload it again. Cleared once saved, unless the author has picked another meanwhile.
  selectedFiles() {
    return Array.from(this.element.querySelectorAll("input[type=file]"))
      .filter(input => input.files.length)
      .map(input => [input, input.files[0]])
  }

  forgetUploaded(uploads) {
    uploads.forEach(([input, file]) => { if (input.files[0] === file) input.value = "" })
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
    url.searchParams.set("preview_locale", this.localeValue)
    frame.src = url.pathname + url.search
    frame.reload()
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
    return template.replace(/%\{(\w+)\}/g, (_, key) => interpolations[key] ?? "")
  }

  // editor-layout:locale — the preview follows the tab.
  showLocale(event) {
    this.localeValue = event.detail.locale
    this.reloadPreview()
  }
}
