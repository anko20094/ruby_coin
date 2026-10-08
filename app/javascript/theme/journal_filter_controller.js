import { Controller } from "@hotwired/stimulus"

const reduced = () => window.matchMedia("(prefers-reduced-motion: reduce)").matches

const withoutHash = (href) => {
  const url = new URL(href, window.location.href)
  url.hash = ""
  return url.href
}

export default class extends Controller {
  // The journal's tag chips, orders and pager. Each is a plain link to the list it describes and
  // still works as one; with script, picking one asks journal#index for the filter and the list
  // alone (?partial=1), swaps them in where they are and pushes the address, so the page does not
  // reload and jump back to the top. Back and forward fetch the list their address names.
  //
  // The entries this controller pushed carry the list's address (history.state.journalFilter).
  // Any other step — a skip link's #main, an anchor after live search moved the address to
  // /search?query=… — fetches nothing unless its address names a different list on this page:
  // a fragment alone neither refetches the list nor reloads it.
  static targets = ["filter", "list", "status"]

  connect() {
    this.path = window.location.pathname
    this.show(withoutHash(window.location.href))
    history.replaceState({ ...history.state, journalFilter: this.shown }, "")
    this.onPop = (event) => this.restore(event)
    window.addEventListener("popstate", this.onPop)
  }

  disconnect() {
    window.removeEventListener("popstate", this.onPop)
    this.pending?.abort()
  }

  follow(event) {
    const link = event.target.closest("a[data-journal-filter-key]")
    if (!link || !this.element.contains(link)) return
    // A new tab, a new window or a download is the browser's to handle.
    if (event.defaultPrevented || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return
    // While live search shows its results the list here is out of the page; the plain link
    // leaves the search for the list it names, which is what the reader asked for.
    if (document.getElementById("journal-live")?.hidden === false) return

    event.preventDefault()
    this.load(link.href, { link })
  }

  restore(event) {
    if (event.state?.liveQuery) return

    const marked = event.state?.journalFilter
    const url = marked ?? (window.location.pathname === this.path ? withoutHash(window.location.href) : null)
    if (!url) return
    // Live search may still hold the list out of the page; it hands it back before the swap.
    window.dispatchEvent(new CustomEvent("journal:leave-search"))
    if (url === this.shown) return
    if (new URL(url).pathname !== this.path) return window.location.reload()

    this.load(url, { push: false })
  }

  async load(url, { link = null, push = true } = {}) {
    this.pending?.abort()
    this.pending = new AbortController()
    const key = link?.dataset.journalFilterKey
    const anchorTop = link?.getBoundingClientRect().top
    const scroll = link?.hasAttribute("data-journal-filter-scroll")

    const request = new URL(url)
    request.hash = ""
    request.searchParams.set("partial", "1")
    this.element.setAttribute("aria-busy", "true")

    try {
      const response = await fetch(request, { headers: { Accept: "text/html" }, signal: this.pending.signal })
      // Anything but the fragment: let the browser go to the page the link names.
      if (!response.ok) return window.location.assign(url)

      this.swap(await response.text())
      this.show(withoutHash(url))
      if (push) history.pushState({ journalFilter: this.shown }, "", url)
      this.settle(key, anchorTop, scroll)
    } catch (error) {
      if (error.name !== "AbortError") window.location.assign(url)
    } finally {
      this.element.removeAttribute("aria-busy")
    }
  }

  // Live search reads it to know which list it is standing in front of.
  show(url) {
    this.shown = url
    this.element.dataset.shown = url
  }

  swap(html) {
    const fragment = document.createRange().createContextualFragment(html)
    const filter = fragment.querySelector("[data-journal-filter-target='filter']")
    const list = fragment.querySelector("[data-journal-filter-target='list']")
    if (filter && this.hasFilterTarget) this.filterTarget.replaceWith(filter)
    if (list && this.hasListTarget) this.listTarget.replaceWith(list)

    const summary = list?.dataset.summary || list?.textContent.trim() || ""
    // Emptied first, so the same count said twice in a row is still read out.
    this.statusTarget.textContent = ""
    requestAnimationFrame(() => { this.statusTarget.textContent = summary })
  }

  // The chip just pressed stays under the pointer and keeps focus; a page step brings the top of
  // the list into view, as a new page would.
  settle(key, anchorTop, scroll) {
    if (scroll) {
      this.element.scrollIntoView({ block: "start", behavior: reduced() ? "auto" : "smooth" })
      this.listTarget.focus({ preventScroll: true })
      return
    }

    const control = key && this.element.querySelector(`[data-journal-filter-key="${key}"]`)
    if (!control) return

    if (anchorTop !== undefined) window.scrollBy(0, control.getBoundingClientRect().top - anchorTop)
    control.focus({ preventScroll: true })
  }
}
