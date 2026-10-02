import { Controller } from "@hotwired/stimulus"

// Select a passage, press Q, get it as a card — the site's one playful moment, and a demo of
// the kind of card ImageMaker renders.
//
// Deliberately quiet: nothing appears until there is a real selection, nothing fires while
// someone is typing, and the whole thing is inert under prefers-reduced-motion except that it
// does not animate.
const MIN_LENGTH = 12
const MAX_LENGTH = 320
// Й is where Q sits on a Ukrainian keyboard.
const KEYS = ["q", "й"]

export default class extends Controller {
  static targets = ["hint", "card", "quote"]

  connect() {
    this.onSelect = () => this.offerCard()
    this.onKey = (event) => this.maybeOpen(event)

    document.addEventListener("selectionchange", this.onSelect)
    window.addEventListener("keydown", this.onKey)
  }

  disconnect() {
    document.removeEventListener("selectionchange", this.onSelect)
    window.removeEventListener("keydown", this.onKey)
  }

  selectedText() {
    const selection = window.getSelection()
    const text = selection?.toString().trim() ?? ""
    return text.length >= MIN_LENGTH ? text.slice(0, MAX_LENGTH) : null
  }

  offerCard() {
    if (this.cardTarget.open) return

    const text = this.selectedText()
    if (!text) return this.hideHint()

    const range = window.getSelection().getRangeAt(0).getBoundingClientRect()
    if (range.width === 0 && range.height === 0) return this.hideHint()

    this.hintTarget.hidden = false
    this.hintTarget.style.top = `${Math.max(8, range.top + window.scrollY - 34)}px`
    this.hintTarget.style.left = `${range.left + window.scrollX + range.width / 2}px`
  }

  hideHint() {
    this.hintTarget.hidden = true
  }

  maybeOpen(event) {
    if (event.metaKey || event.ctrlKey || event.altKey) return
    if (!KEYS.includes(event.key?.toLowerCase())) return
    if (this.typing(event.target)) return

    const text = this.selectedText()
    if (!text) return

    event.preventDefault()
    this.open(text)
  }

  typing(element) {
    if (!element) return false
    const name = element.tagName?.toLowerCase()
    return name === "input" || name === "textarea" || element.isContentEditable
  }

  open(text) {
    // The passage sets its own size: a sentence gets to be a headline, a paragraph does not.
    const size = text.length > 220 ? "sm" : text.length > 110 ? "md" : "lg"
    this.quoteTarget.className = `rc-quote__text is-${size}`
    this.quoteTarget.textContent = text

    this.hideHint()
    this.cardTarget.showModal()
  }

  close() {
    if (this.cardTarget.open) this.cardTarget.close()
  }
}
