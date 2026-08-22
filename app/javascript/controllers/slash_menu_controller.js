import { Controller } from "@hotwired/stimulus"
import Trix from "trix"

// Connects to data-controller="slash-menu"
//
// Typing "/" in either body editor opens a small menu; picking a kind shows that kind's
// fields, and inserting posts them to /management/journal_blocks. The server answers with the
// block's signed global id and the same partial the public page renders, so what the editor
// shows is what the article will show.
export default class extends Controller {
  static targets = ["menu", "fields", "error"]

  connect() {
    this.editor = null
    this.kind = null
    this.onKeydown = this.handleKeydown.bind(this)
    this.element.querySelectorAll('trix-editor').forEach(editor => {
      editor.addEventListener('keydown', this.onKeydown)
    })
  }

  disconnect() {
    this.element.querySelectorAll('trix-editor').forEach(editor => {
      editor.removeEventListener('keydown', this.onKeydown)
    })
  }

  handleKeydown(event) {
    if (event.key !== '/') return

    event.preventDefault()
    this.editor = event.currentTarget
    this.open()
  }

  open() {
    this.errorTarget.hidden = true
    this.fieldsTargets.forEach(group => { group.hidden = true })
    this.menuTarget.hidden = false
  }

  close() {
    this.menuTarget.hidden = true
    this.kind = null
    this.editor?.focus()
  }

  pick(event) {
    this.kind = event.currentTarget.dataset.kind
    this.fieldsTargets.forEach(group => {
      group.hidden = group.dataset.kind !== this.kind
    })
    this.currentFields()?.querySelector('[data-field]')?.focus()
  }

  insert() {
    if (!this.kind || !this.editor) return

    const payload = {}
    this.currentFields().querySelectorAll('[data-field]').forEach(input => {
      payload[input.dataset.field] = input.value
    })

    fetch('/management/journal_blocks', {
      method: 'POST',
      headers: {
        'X-CSRF-Token': document.querySelector('meta[name=csrf-token]').getAttribute('content'),
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ kind: this.kind, payload: payload }),
    })
      .then(response => response.json().then(data => ({ ok: response.ok, data })))
      .then(({ ok, data }) => {
        if (!ok) return this.fail(data.errors)

        this.editor.editor.insertAttachment(new Trix.Attachment({ sgid: data.sgid, content: data.content }))
        this.currentFields().querySelectorAll('[data-field]').forEach(input => { input.value = '' })
        this.close()
      })
      .catch(() => this.fail())
  }

  fail(errors) {
    this.errorTarget.textContent = (errors || []).join(', ') || 'could not insert the block'
    this.errorTarget.hidden = false
  }

  currentFields() {
    return this.fieldsTargets.find(group => group.dataset.kind === this.kind)
  }
}
