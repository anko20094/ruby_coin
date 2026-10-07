import { Controller } from "@hotwired/stimulus"
import { postJSON } from "../lib/http"

export default class extends Controller {
  static targets = ["button", "status"]
  static values = { url: String, locale: String, phrases: Object }

  editorFor(locale) {
    return window.tinymce?.get(`post_description_${locale}`)
  }

  fetchData() {
    const source = this.editorFor(this.localeValue)
    const target = (window.tinymce?.get() || [])
      .find(editor => editor !== source && editor.id.startsWith("post_description_"))
    const button = this.buttonTarget

    if (!source || !target || button.disabled) return
    if (target.getContent({ format: "text" }).trim() && !window.confirm(this.phrase("overwrite"))) return

    this.setState("busy")

    postJSON(this.urlValue, { input_data: source.getContent(), locale: this.localeValue })
      .then(response => {
        if (!response.ok) throw new Error(`translate answered ${response.status}`)
        return response.json()
      })
      .then(data => {
        if (!data.data?.trim()) throw new Error("translate answered nothing")

        target.setContent(data.data)
        // setContent alone leaves the form thinking nothing changed, so the autosave never runs
        // and the translation is lost on the next reload.
        target.save()
        target.targetElm.dispatchEvent(new Event("input", { bubbles: true }))
        this.setState("done")
      })
      .catch(() => this.setState("failed"))
  }

  setState(state) {
    const button = this.buttonTarget
    button.disabled = state === "busy"
    button.setAttribute("aria-busy", String(state === "busy"))
    button.dataset.state = state

    const key = { busy: "translating", done: "done", failed: "error" }[state]
    if (this.hasStatusTarget) this.statusTarget.textContent = this.phrase(key)
  }

  phrase(key) {
    return this.phrasesValue[key] || key
  }
}
