import { Controller } from "@hotwired/stimulus"

// The character first, the physical key only when the layout types a non-Latin letter — the
// palette's rule, so J and K work on a Ukrainian keyboard without stealing a Dvorak typist's
// keys.
const isKey = (event, letter) =>
  event.key?.toLowerCase() === letter ||
  (!/^[a-z]$/i.test(event.key ?? "") && event.code === `Key${letter.toUpperCase()}`)

const typing = (target) =>
  target instanceof HTMLElement &&
  (target.isContentEditable || /^(INPUT|TEXTAREA|SELECT)$/.test(target.tagName))

export default class extends Controller {
  // J/K through a list, Enter to open, / to search, Esc to let go. The rows are links already, so
  // moving means focusing the next one: Enter, middle-click and the context menu then work as
  // they do for any link. Rows are looked up on every keypress rather than once, because live
  // search swaps the list under the controller.
  static targets = ["search", "hint"]
  static values = { item: String }

  connect() {
    this.onKey = (event) => this.key(event)
    window.addEventListener("keydown", this.onKey)
  }

  disconnect() {
    window.removeEventListener("keydown", this.onKey)
  }

  // The journal's filter swaps the hint in with the list, drawn hidden like the first one.
  hintTargetConnected(hint) {
    hint.hidden = false
  }

  key(event) {
    if (event.defaultPrevented || event.metaKey || event.ctrlKey || event.altKey) return
    if (typing(event.target) || document.querySelector("dialog[open]")) return

    if (isKey(event, "j")) {
      this.move(event, 1)
    } else if (isKey(event, "k")) {
      this.move(event, -1)
    } else if (event.key === "/") {
      event.preventDefault()
      this.search()
    } else if (event.key === "Escape" && this.current) {
      this.release()
    } else if (event.key === "Enter" && this.current && this.unfocused) {
      // A click on blank page dropped focus to the body, but the row is still marked: open that
      // one. Focus on anything else — a link, a button, the row itself — keeps its own Enter.
      event.preventDefault()
      this.linkIn(this.current)?.click()
    } else if (event.key === "Tab" && this.current) {
      // Tabbing on moves focus off the mark, so the mark goes too.
      this.current.classList.remove("is-keyed")
      this.current = null
    }
  }

  move(event, step) {
    const items = this.items
    if (items.length === 0) return

    event.preventDefault()
    // A row the reader tabbed or clicked to counts as where they are.
    const focused = items.find((item) => item.contains(document.activeElement))
    const from = items.indexOf(focused ?? this.current)
    const start = step > 0 ? 0 : items.length - 1
    const index = from === -1 ? start : Math.min(items.length - 1, Math.max(0, from + step))
    this.mark(items[index])
  }

  mark(item) {
    this.current?.classList.remove("is-keyed")
    this.current = item
    item.classList.add("is-keyed")

    const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    this.linkIn(item)?.focus({ preventScroll: true })
    item.scrollIntoView({ block: "nearest", behavior: reduced ? "auto" : "smooth" })
  }

  release() {
    this.current.classList.remove("is-keyed")
    if (this.current.contains(document.activeElement)) document.activeElement.blur()
    this.current = null
  }

  // The page's own field if it has one; otherwise the site-wide palette.
  search() {
    if (this.hasSearchTarget) {
      this.searchTarget.focus()
      this.searchTarget.select()
    } else {
      window.dispatchEvent(new CustomEvent("rubycoin:palette"))
    }
  }

  linkIn(item) {
    return item.matches("a[href]") ? item : item.querySelector("a[href]")
  }

  get unfocused() {
    return !document.activeElement || document.activeElement === document.body
  }

  get items() {
    return Array.from(this.element.querySelectorAll(this.itemValue))
  }

  get current() {
    return this.currentItem?.isConnected ? this.currentItem : null
  }

  set current(item) {
    this.currentItem = item
  }
}
