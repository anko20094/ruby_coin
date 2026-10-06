import { Controller } from "@hotwired/stimulus"

const DEBOUNCE_MS = 250
const MIN_LENGTH = 2

export default class extends Controller {
  // The journal's search field, answered as the reader types. The form is a plain GET to
  // /search and still is: this only asks the same action for its results alone (?partial=1),
  // puts them where the list was, and keeps the address bar on the search a reload would show.
  // Below two characters, or on Esc, the list the page came with goes back exactly as it was.
  static targets = ["status"]
  static values = { results: String }

  connect() {
    this.input = this.element.querySelector("input[type=search]")
    this.container = document.getElementById(this.resultsValue)
    if (!this.input || !this.container) return

    this.home = window.location.href
    this.onInput = () => this.schedule()
    this.onKey = (event) => this.key(event)
    this.input.addEventListener("input", this.onInput)
    this.input.addEventListener("keydown", this.onKey)
    // Results arrive as the reader types, so the submit button has nothing left to do.
    this.element.classList.add("is-live")
  }

  disconnect() {
    this.input?.removeEventListener("input", this.onInput)
    this.input?.removeEventListener("keydown", this.onKey)
    this.element.classList.remove("is-live")
    clearTimeout(this.timer)
    this.pending?.abort()
  }

  key(event) {
    if (event.key !== "Escape" || !this.input.value) return

    event.preventDefault()
    this.input.value = ""
    // As an input event, so the clear button (search-clear) hears it too.
    this.input.dispatchEvent(new Event("input", { bubbles: true }))
  }

  schedule() {
    clearTimeout(this.timer)
    this.pending?.abort()

    if (this.query.length < MIN_LENGTH) {
      this.restore()
    } else {
      this.timer = setTimeout(() => this.fetchResults(), DEBOUNCE_MS)
    }
  }

  // An answer to an earlier keystroke must not land after a later one, so the request in flight
  // is cancelled as soon as the text changes.
  async fetchResults() {
    const query = this.query
    const params = new URLSearchParams({ query, partial: "1" })
    this.pending = new AbortController()

    try {
      const response = await fetch(`${this.element.action}?${params}`, {
        headers: { Accept: "text/html" },
        signal: this.pending.signal,
      })
      // Anything but an answer leaves the page as it is: the form still submits.
      if (!response.ok) return

      this.show(await response.text(), query)
    } catch (error) {
      if (error.name !== "AbortError") throw error
    }
  }

  show(html, query) {
    this.takeList()
    this.container.innerHTML = html
    this.container.hidden = false
    this.announce(this.container.querySelector("[data-summary]")?.dataset.summary ?? "")
    history.replaceState(history.state, "", `${this.element.action}?${new URLSearchParams({ query })}`)
  }

  restore() {
    if (!this.taken) return

    this.container.after(...this.taken)
    this.taken = null
    this.container.replaceChildren()
    this.container.hidden = true
    this.announce("")
    history.replaceState(history.state, "", this.home)
  }

  // The page's own list, lifted out rather than hidden, so nothing that walks the page (J/K)
  // meets two lists.
  takeList() {
    if (this.taken) return

    this.taken = []
    for (let node = this.container.nextElementSibling; node; node = node.nextElementSibling) this.taken.push(node)
    this.taken.forEach((node) => node.remove())
  }

  announce(text) {
    if (this.hasStatusTarget) this.statusTarget.textContent = text
  }

  get query() {
    return this.input.value.trim()
  }
}
