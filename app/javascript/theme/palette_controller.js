import { Controller } from "@hotwired/stimulus"

// ⌘K / Ctrl+K. Pages, cases and journal entries in one list — the server answers, because the
// journal's search is a Postgres full-text search and the prototype only filtered in memory
// for want of a server.
//
// Built on <dialog>, which brings the focus trap, the Escape handler and the inert background
// with it rather than having them reimplemented here and got subtly wrong.
const DEBOUNCE_MS = 140

export default class extends Controller {
  static targets = ["dialog", "input", "results", "empty"]
  static values = { url: String }

  connect() {
    this.index = 0
    this.onKey = (event) => this.shortcut(event)
    window.addEventListener("keydown", this.onKey)
  }

  disconnect() {
    window.removeEventListener("keydown", this.onKey)
    clearTimeout(this.timer)
  }

  shortcut(event) {
    if (event.key?.toLowerCase() !== "k" || !(event.metaKey || event.ctrlKey)) return
    event.preventDefault()
    this.dialogTarget.open ? this.close() : this.open()
  }

  open() {
    this.dialogTarget.showModal()
    this.inputTarget.select()
  }

  close() {
    if (this.dialogTarget.open) this.dialogTarget.close()
  }

  // Clicking the backdrop closes. <dialog> reports those clicks as landing on the dialog
  // itself, so the test is whether the point is outside its box rather than what it hit.
  backdrop(event) {
    if (event.target !== this.dialogTarget) return

    const box = this.dialogTarget.getBoundingClientRect()
    const outside =
      event.clientX < box.left || event.clientX > box.right ||
      event.clientY < box.top || event.clientY > box.bottom
    if (outside) this.close()
  }

  search() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.fetchResults(), DEBOUNCE_MS)
  }

  async fetchResults() {
    const query = this.inputTarget.value.trim()
    if (!query) return this.render([])

    const response = await fetch(`${this.urlValue}?query=${encodeURIComponent(query)}`, {
      headers: { Accept: "application/json" },
    }).catch(() => null)
    if (!response?.ok) return this.render([])

    const { results } = await response.json()
    this.render(results)
  }

  render(results) {
    this.index = 0
    this.resultsTarget.replaceChildren(...results.map((result, position) => this.row(result, position)))
    this.emptyTarget.hidden = results.length > 0
    this.resultsTarget.hidden = results.length === 0
    this.announce()
  }

  // aria-selected alone moves a highlight nothing announces: the caret stays in the input, so
  // the input is what has to name the option the arrows are on.
  announce() {
    const active = this.resultsTarget.children[this.index]
    if (active) {
      this.inputTarget.setAttribute("aria-activedescendant", active.id)
    } else {
      this.inputTarget.removeAttribute("aria-activedescendant")
    }
  }

  row(result, position) {
    const link = document.createElement("a")
    link.className = "rc-palette__row"
    link.id = `rc-palette-row-${position}`
    link.href = result.url
    link.setAttribute("role", "option")
    link.setAttribute("aria-selected", position === 0 ? "true" : "false")

    const kind = document.createElement("span")
    kind.className = "rc-palette__kind"
    kind.textContent = result.label || result.kind

    const title = document.createElement("span")
    title.className = "rc-palette__title"
    title.textContent = result.title

    const hint = document.createElement("span")
    hint.className = "rc-palette__hint"
    hint.textContent = result.hint || ""

    link.append(kind, title, hint)
    return link
  }

  // ↑ ↓ ⏎ over the list while the caret stays in the input.
  navigate(event) {
    const rows = [...this.resultsTarget.children]
    if (rows.length === 0) return

    if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      event.preventDefault()
      const step = event.key === "ArrowDown" ? 1 : -1
      this.index = (this.index + step + rows.length) % rows.length
      rows.forEach((row, position) => row.setAttribute("aria-selected", position === this.index ? "true" : "false"))
      rows[this.index].scrollIntoView({ block: "nearest" })
      this.announce()
    } else if (event.key === "Enter") {
      event.preventDefault()
      rows[this.index]?.click()
    }
  }
}
