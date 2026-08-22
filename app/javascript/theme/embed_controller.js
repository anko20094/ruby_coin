import { Controller } from "@hotwired/stimulus"

// Click-to-load embeds. The server renders a plain link, so with JavaScript off — or before
// the reader asks — no third-party request is made and nothing from another origin can watch
// the page. Only providers named here get an inline frame; anything else stays a link and
// opens in a new tab, which is the honest fallback.
//
// Note for the CSP work in W8: the iframe src below is what frame-src has to allow.
const PROVIDERS = [
  { host: /(^|\.)youtube\.com$/, frame: (url) => `https://www.youtube-nocookie.com/embed/${url.searchParams.get('v')}` },
  { host: /(^|\.)youtu\.be$/, frame: (url) => `https://www.youtube-nocookie.com/embed/${url.pathname.slice(1)}` },
  { host: /(^|\.)vimeo\.com$/, frame: (url) => `https://player.vimeo.com/video/${url.pathname.split('/').filter(Boolean)[0]}` },
]

export default class extends Controller {
  static values = { url: String }

  load(event) {
    const url = this.parsedUrl()
    if (!url) return

    const provider = PROVIDERS.find(candidate => candidate.host.test(url.hostname))
    if (!provider) return

    const src = provider.frame(url)
    if (!src || src.endsWith('/null') || src.endsWith('/')) return

    event.preventDefault()

    const frame = document.createElement('iframe')
    frame.className = 'jn-embed__frame'
    frame.src = src
    frame.allow = 'accelerometer; autoplay; clipboard-write; encrypted-media; picture-in-picture'
    frame.allowFullscreen = true
    frame.title = this.element.querySelector('.jn-embed__caption')?.textContent || url.hostname

    this.element.querySelector('.jn-embed__facade').replaceWith(frame)
  }

  parsedUrl() {
    try {
      return new URL(this.urlValue)
    } catch {
      return null
    }
  }
}
