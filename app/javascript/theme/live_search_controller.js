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

    this.onInput = () => this.schedule()
    this.onKey = (event) => this.key(event)
    this.onPop = (event) => this.travel(event)
    this.onLeave = () => this.leave()
    this.input.addEventListener("input", this.onInput)
    this.input.addEventListener("keydown", this.onKey)
    window.addEventListener("popstate", this.onPop)
    // The journal filter is about to swap the list: the search gives it back first.
    window.addEventListener("journal:leave-search", this.onLeave)
    // Results arrive as the reader types, so the submit button has nothing left to do.
    this.element.classList.add("is-live")
  }

  disconnect() {
    this.input?.removeEventListener("input", this.onInput)
    this.input?.removeEventListener("keydown", this.onKey)
    window.removeEventListener("popstate", this.onPop)
    window.removeEventListener("journal:leave-search", this.onLeave)
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
    // The address and history entry to go back to are the ones the search started from: the
    // filter may have moved them to a tag, an order or a page since the page loaded.
    if (!this.taken) this.markHome()
    this.takeList()
    this.container.innerHTML = html
    this.container.hidden = false
    this.announce(this.container.querySelector("[data-summary]")?.dataset.summary ?? "")
    // Its own mark, not the filter's: the filter must not take this entry for one of its lists.
    history.replaceState({ liveQuery: query }, "", `${this.element.action}?${new URLSearchParams({ query })}`)
  }

  restore() {
    if (!this.giveBack() || !this.home) return

    history.replaceState(this.homeState, "", this.home)
  }

  // Where Esc returns to. Normally the address the search started from; after Forward back onto
  // a search, the address is the search's own, so the list behind it is the filter's.
  markHome() {
    const shown = document.querySelector("[data-controller~='journal-filter']")?.dataset.shown
    if (history.state?.liveQuery) {
      this.home = shown ?? null
      this.homeState = shown ? { journalFilter: shown } : null
    } else {
      this.home = window.location.href
      this.homeState = history.state
    }
  }

  // The list back in the page and the results gone; the address is the caller's business.
  giveBack() {
    if (!this.taken) return false

    this.container.after(...this.taken)
    this.taken = null
    this.container.replaceChildren()
    this.container.hidden = true
    this.announce("")
    return true
  }

  // Back or forward: onto a search this controller wrote, run it again; onto anything else,
  // step out of the search without writing history, and let the filter load its list.
  travel(event) {
    const query = event.state?.liveQuery
    if (query) {
      this.input.value = query
      this.input.dispatchEvent(new Event("input", { bubbles: true }))
      return
    }
    this.leave()
  }

  leave() {
    clearTimeout(this.timer)
    this.pending?.abort()
    if (!this.giveBack() && !this.input.value) return

    this.input.value = ""
    this.input.dispatchEvent(new Event("input", { bubbles: true }))
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
