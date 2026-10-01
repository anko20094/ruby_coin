import { Controller } from "@hotwired/stimulus"

// ⌘K / Ctrl+K. Pages, cases and journal entries in one list — the server answers, because the
// journal's search is a Postgres full-text search and the prototype only filtered in memory
// for want of a server.
//
// Built on <dialog>, which brings the focus trap, the Escape handler and the inert background
// with it rather than having them reimplemented here and got subtly wrong.
const DEBOUNCE_MS = 140

// Match the character, falling back to the physical key only when the layout types a
// non-Latin letter (Ukrainian): event.code alone would also fire for a Dvorak typist's T.
const isK = (event) =>
  event.key?.toLowerCase() === "k" || (!/^[a-z]$/i.test(event.key ?? "") && event.code === "KeyK")

export default class extends Controller {
  static targets = ["dialog", "input", "results", "empty"]
  static values = { url: String, allUrl: String, allLabel: String, none: String }

  connect() {
    this.index = 0
    this.prompt = this.emptyTarget.textContent
    this.onKey = (event) => this.shortcut(event)
    window.addEventListener("keydown", this.onKey)
  }

  disconnect() {
    window.removeEventListener("keydown", this.onKey)
    clearTimeout(this.timer)
    this.pending?.abort()
  }

  shortcut(event) {
    if (!(event.metaKey || event.ctrlKey) || !isK(event)) return
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

  // An answer to an earlier keystroke must not land after a later one, or on a box that has
  // since been cleared, so the request in flight is cancelled the moment the text changes.
  search() {
    clearTimeout(this.timer)
    this.pending?.abort()
    this.timer = setTimeout(() => this.fetchResults(), DEBOUNCE_MS)
  }

  async fetchResults() {
    const query = this.inputTarget.value.trim()
    if (!query) return this.render([])

    this.pending = new AbortController()
    try {
      const response = await fetch(`${this.urlValue}?query=${encodeURIComponent(query)}`, {
        headers: { Accept: "application/json" },
        signal: this.pending.signal,
      })
      if (!response.ok) return this.render([])

      const { results } = await response.json()
      this.render(results)
    } catch (error) {
      if (error.name !== "AbortError") this.render([])
    }
  }

  render(results) {
    const query = this.inputTarget.value.trim()
    const rows = results.map((result, position) => this.row(result, position))
    if (rows.length > 0) rows.push(this.allRow(query, rows.length))

    this.index = 0
    this.resultsTarget.replaceChildren(...rows)
    this.emptyTarget.textContent = query ? this.noneValue : this.prompt
    this.emptyTarget.hidden = rows.length > 0
    this.resultsTarget.hidden = rows.length === 0
    this.inputTarget.setAttribute("aria-expanded", String(rows.length > 0))
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
    return this.option(position, result.url, result.label || result.kind, result.title, result.hint)
  }

  // The list is cut at what fits a palette; this is the way to the rest.
  allRow(query, position) {
    const url = `${this.allUrlValue}?query=${encodeURIComponent(query)}`
    return this.option(position, url, "→", this.allLabelValue, query)
  }

  option(position, href, kindText, titleText, hintText) {
    const link = document.createElement("a")
    link.className = "rc-palette__row"
    link.id = `rc-palette-row-${position}`
    link.href = href
    link.setAttribute("role", "option")
    link.setAttribute("aria-selected", position === 0 ? "true" : "false")

    const kind = document.createElement("span")
    kind.className = "rc-palette__kind"
    kind.textContent = kindText

    const title = document.createElement("span")
    title.className = "rc-palette__title"
    title.textContent = titleText

    const hint = document.createElement("span")
    hint.className = "rc-palette__hint"
    hint.textContent = hintText || ""

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
