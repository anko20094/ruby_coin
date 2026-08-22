import { Controller } from "@hotwired/stimulus"
import Translations from '../i18n/aitranslation'

// Connects to data-controller="aitranslation"
//
// Copies the current locale's body into the other locale's editor via the AI translation
// endpoint. Both bodies are Action Text rich texts, so this reads and writes Trix documents
// rather than the iframes the old TinyMCE editor used.
export default class extends Controller {
  editorFor(locale) {
    return this.element.querySelector(`trix-editor[input="post_description_${locale}"]`)
  }

  fetchData() {
    const locale = this.data.get("locale")
    const source = this.editorFor(locale)
    const target = Array.from(this.element.querySelectorAll('trix-editor'))
      .find(editor => editor !== source)
    const button = document.querySelector("#translation-button")
    const i18n = Translations[document.querySelector('body').dataset.lang]

    if (!source || !target) return

    button.innerHTML = i18n['translating']

    fetch('/management/posts/translate', {
      method: 'POST',
      headers: {
        'X-CSRF-Token': document.querySelector("meta[name=csrf-token]").getAttribute("content"),
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ input_data: source.value, locale: locale }),
    })
    .then(response => response.json())
    .then(data => {
      target.editor.loadHTML(data.data)
      button.innerHTML = i18n['done']
      button.style.backgroundColor = 'darkgreen'
    })
    .catch(() => {
      button.innerHTML = i18n['error']
      button.style.backgroundColor = 'goldenrod'
    })
  }
}
