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
const FILENAME = "rubycoin-quote.png"
// The PNG is drawn wider than the card on screen and at twice the pixels, so it holds up
// when it is posted somewhere that shows it large.
const EXPORT_WIDTH = 1080
const EXPORT_SCALE = 2
// Only for a browser whose canvas cannot read the tokens' oklch(): the same colours in sRGB.
const FALLBACK = { paper: "#f7e6e6", ruby: "#8c1d37", ink: "#6b6460" }

export default class extends Controller {
  static targets = ["hint", "card", "quote", "mark", "copy", "status"]
  static values = { copied: String, saved: String, failed: String }

  connect() {
    const clipboardTakesImages = window.ClipboardItem && navigator.clipboard?.write
    if (this.hasCopyTarget && clipboardTakesImages) this.copyTarget.hidden = false

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

    this.statusTarget.textContent = ""
    this.hideHint()
    this.cardTarget.showModal()
  }

  // A click anywhere on the card closes it, except on its own buttons.
  close(event) {
    if (event?.target?.closest?.(".rc-quote__actions")) return
    if (this.cardTarget.open) this.cardTarget.close()
  }

  async download() {
    try {
      const blob = await this.drawPng()
      const url = URL.createObjectURL(blob)
      const link = document.createElement("a")
      link.href = url
      link.download = FILENAME
      document.body.append(link)
      link.click()
      link.remove()
      setTimeout(() => URL.revokeObjectURL(url), 1000)
      this.say(this.savedValue)
    } catch {
      this.say(this.failedValue)
    }
  }

  // The blob goes in as a promise: Safari only allows the write inside the click itself, and
  // drawing the card takes longer than that.
  async copyImage() {
    try {
      await navigator.clipboard.write([new ClipboardItem({ "image/png": this.drawPng() })])
      this.say(this.copiedValue)
    } catch {
      this.say(this.failedValue)
    }
  }

  say(message) {
    this.statusTarget.textContent = message
  }

  // The card, drawn again on a canvas from what is on screen: the same text, the same faces and
  // colours read off the live elements, and the gem from its own SVG.
  async drawPng() {
    await document.fonts.ready

    const card = getComputedStyle(this.cardTarget)
    const quote = getComputedStyle(this.quoteTarget)
    const label = getComputedStyle(this.markTarget)
    const ratio = EXPORT_WIDTH / this.cardTarget.getBoundingClientRect().width

    const quoteSize = parseFloat(quote.fontSize) * ratio
    const quoteFont = `${quote.fontStyle} ${quote.fontWeight} ${quoteSize}px ${quote.fontFamily}`
    const labelSize = parseFloat(label.fontSize) * ratio
    const labelFont = `${label.fontWeight} ${labelSize}px ${label.fontFamily}`
    await Promise.all([document.fonts.load(quoteFont), document.fonts.load(labelFont)])

    const padX = parseFloat(card.paddingLeft) * ratio
    const padTop = parseFloat(card.paddingTop) * ratio
    const padBottom = parseFloat(card.paddingBottom) * ratio
    const lineHeight = (parseFloat(quote.lineHeight) || parseFloat(quote.fontSize) * 1.22) * ratio
    const markGap = parseFloat(label.marginTop) * ratio
    const gemSize = (this.markTarget.querySelector("svg")?.getBoundingClientRect().width || 18) * ratio

    const canvas = document.createElement("canvas")
    const context = canvas.getContext("2d")
    const quoteTracking = `${(parseFloat(quote.letterSpacing) || 0) * ratio}px`
    context.font = quoteFont
    if ("letterSpacing" in context) context.letterSpacing = quoteTracking
    const [open, close] = document.documentElement.lang === "uk" ? ["«", "»"] : ["“", "”"]
    const lines = wrap(context, `${open}${this.quoteTarget.textContent}${close}`, EXPORT_WIDTH - padX * 2)
    const height = Math.ceil(padTop + lines.length * lineHeight + markGap + gemSize + padBottom)

    canvas.width = EXPORT_WIDTH * EXPORT_SCALE
    canvas.height = height * EXPORT_SCALE
    context.scale(EXPORT_SCALE, EXPORT_SCALE)

    context.fillStyle = colour(context, card.backgroundColor, FALLBACK.paper)
    context.fillRect(0, 0, EXPORT_WIDTH, height)

    // The card is lit from its top-right corner by a CSS gradient, which a canvas cannot read
    // back; the same light is drawn again in the same place.
    if (card.backgroundImage !== "none") {
      const radius = 600 * ratio
      const light = context.createRadialGradient(EXPORT_WIDTH * 0.9, -0.1 * height, 0, EXPORT_WIDTH * 0.9, -0.1 * height, radius)
      light.addColorStop(0, "rgba(150, 18, 58, 0.3)")
      light.addColorStop(0.65, "rgba(150, 18, 58, 0)")
      context.fillStyle = light
      context.fillRect(0, 0, EXPORT_WIDTH, height)
    }

    context.font = quoteFont
    if ("letterSpacing" in context) context.letterSpacing = quoteTracking
    context.fillStyle = colour(context, quote.color, FALLBACK.ruby)
    context.textBaseline = "alphabetic"
    lines.forEach((line, index) => {
      // The baseline sits where the browser puts it: the half-leading above, then the ascent.
      const baseline = padTop + index * lineHeight + (lineHeight - quoteSize) / 2 + quoteSize * 0.8
      context.fillText(line, padX, baseline)
    })

    const markTop = padTop + lines.length * lineHeight + markGap
    const gem = await gemImage(this.markTarget.querySelector("svg"), gemSize * EXPORT_SCALE)
    if (gem) context.drawImage(gem, padX, markTop, gemSize, gemSize)

    context.font = labelFont
    if ("letterSpacing" in context) context.letterSpacing = `${(parseFloat(label.letterSpacing) || 0) * ratio}px`
    context.fillStyle = colour(context, label.color, FALLBACK.ink)
    context.textBaseline = "middle"
    context.fillText("rubyco.in", padX + gemSize + (parseFloat(label.columnGap) || 8) * ratio, markTop + gemSize / 2)

    return new Promise((resolve, reject) => {
      canvas.toBlob((blob) => (blob ? resolve(blob) : reject(new Error("toBlob"))), "image/png")
    })
  }
}

// Greedy word wrap against the canvas's own measurements, which are the export font's.
function wrap(context, text, width) {
  const lines = []
  let line = ""
  text.split(/\s+/).forEach((word) => {
    const candidate = line ? `${line} ${word}` : word
    if (line && context.measureText(candidate).width > width) {
      lines.push(line)
      line = word
    } else {
      line = candidate
    }
  })
  if (line) lines.push(line)
  return lines
}

// A canvas that cannot parse a colour keeps the previous one, so a sentinel tells us.
function colour(context, value, fallback) {
  const sentinel = "#010203"
  context.fillStyle = sentinel
  context.fillStyle = value
  return context.fillStyle === sentinel ? fallback : value
}

function gemImage(svg, size) {
  if (!svg) return Promise.resolve(null)

  const copy = svg.cloneNode(true)
  copy.setAttribute("xmlns", "http://www.w3.org/2000/svg")
  copy.setAttribute("width", size)
  copy.setAttribute("height", size)
  copy.removeAttribute("style")
  const markup = new XMLSerializer().serializeToString(copy).replaceAll("currentColor", "#1d1715")
  const url = URL.createObjectURL(new Blob([markup], { type: "image/svg+xml" }))

  return new Promise((resolve) => {
    const image = new Image()
    image.onload = () => {
      URL.revokeObjectURL(url)
      resolve(image)
    }
    image.onerror = () => {
      URL.revokeObjectURL(url)
      resolve(null)
    }
    image.src = url
  })
}
