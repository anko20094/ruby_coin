import { Controller } from "@hotwired/stimulus"
import Translations from '../i18n/aitranslation'

// Connects to data-controller="aitranslation"
//
// Copies the current locale's body into the other locale's editor via the AI translation
// endpoint. Both bodies are Action Text rich texts edited in TinyMCE, so the text is read and
// written through the editor instance rather than off the textarea — the textarea only catches
// up when TinyMCE saves into it, and that is not on every keystroke.
//
// The result is autosaved, so a body already there is replaced only once the author agrees,
// and an answer that is not a translation never reaches it.
export default class extends Controller {
  editorFor(locale) {
    return window.tinymce?.get(`post_description_${locale}`)
  }

  fetchData() {
    const locale = this.data.get("locale")
    const source = this.editorFor(locale)
    const target = (window.tinymce?.get() || [])
      .find(editor => editor !== source && editor.id.startsWith("post_description_"))
    const button = document.querySelector("#translation-button")
    const i18n = Translations[document.querySelector('body').dataset.lang]

    if (!source || !target || button.disabled) return
    if (target.getContent({ format: "text" }).trim() && !window.confirm(i18n['overwrite'])) return

    button.disabled = true
    button.innerHTML = i18n['translating']

    fetch('/management/posts/translate', {
      method: 'POST',
      headers: {
        'X-CSRF-Token': document.querySelector("meta[name=csrf-token]").getAttribute("content"),
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ input_data: source.getContent(), locale: locale }),
    })
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
      button.innerHTML = i18n['done']
      button.style.backgroundColor = 'darkgreen'
    })
    .catch(() => {
      button.innerHTML = i18n['error']
      button.style.backgroundColor = 'goldenrod'
    })
    .finally(() => { button.disabled = false })
  }
}
