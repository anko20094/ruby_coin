import { Controller } from "@hotwired/stimulus"

const GAP = 8

export default class extends Controller {
  // The journal row's preview card. CSS shows it on hover and keyboard focus with or without
  // this; what the script adds is the side it opens on — below the row, or above it when the
  // window has no room below — and the lead as the row's description for a screen reader.
  connect() {
    this.row = this.element.closest("a")
    if (!this.row) return

    const lead = this.element.querySelector(".jn-preview__lead")
    if (lead) this.row.setAttribute("aria-describedby", lead.id)

    this.onEnter = () => this.place()
    this.row.addEventListener("mouseenter", this.onEnter)
    this.row.addEventListener("focus", this.onEnter)
  }

  disconnect() {
    this.row?.removeEventListener("mouseenter", this.onEnter)
    this.row?.removeEventListener("focus", this.onEnter)
  }

  place() {
    const row = this.row.getBoundingClientRect()
    const height = this.element.offsetHeight
    const roomBelow = window.innerHeight - row.bottom
    const above = roomBelow < height + GAP && row.top > height + GAP
    this.element.dataset.place = above ? "above" : "below"
  }
}
