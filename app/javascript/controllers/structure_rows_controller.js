import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="structure-rows"
//
// One StructuredJson field — a case's metrics, the CV's career entries — as a list that can be
// added to, taken from and reordered. Before this, a form drew exactly STRUCTURES[field][:count]
// rows and there was no way to have any other number: a case with five metrics could not be
// written, and one with three had to leave the fourth blank and hope the server dropped it.
//
// The server reads a structured field as an index-keyed hash and sorts by that index, so the
// index is the display order. Every add, remove and move therefore ends in reindex(), which
// rewrites each row's field names from its position on the screen. Ids are not touched: they
// come from a counter that only goes up, so TinyMCE never sees two editors claiming one id.
export default class extends Controller {
  static targets = ["rows", "template", "count", "row"]
  static values = { next: Number }

  connect() {
    this.reindex()
  }

  add() {
    const uid = this.nextValue
    this.nextValue = uid + 1

    this.rowsTarget.insertAdjacentHTML("beforeend", this.templateTarget.innerHTML.replaceAll(PLACEHOLDER, uid))
    this.reindex()

    const added = this.rowTargets[this.rowTargets.length - 1]
    added?.querySelector("input, textarea")?.focus()
    added?.scrollIntoView({ block: "nearest", behavior: "smooth" })
  }

  remove(event) {
    const row = event.currentTarget.closest("[data-structure-rows-target='row']")
    if (!row) return

    // The editors inside go first. Stimulus would disconnect them a microtask later anyway,
    // but by then TinyMCE is holding an iframe whose document has already been detached.
    this.destroyEditorsIn(row)
    row.remove()
    this.reindex()
  }

  moveUp(event) {
    const row = event.currentTarget.closest("[data-structure-rows-target='row']")
    this.swap(row, row?.previousElementSibling)
  }

  moveDown(event) {
    const row = event.currentTarget.closest("[data-structure-rows-target='row']")
    this.swap(row?.nextElementSibling, row)
  }

  // Moving a node detaches it, and a detached TinyMCE iframe loses its document. So the text
  // is written back to the textareas, the editors are torn down, the row moves, and the
  // fields go back to being plain textareas that boot an editor again when they are focused.
  swap(lower, upper) {
    if (!lower || !upper) return

    this.destroyEditorsIn(lower)
    this.destroyEditorsIn(upper)
    upper.before(lower)
    this.reindex()
  }

  destroyEditorsIn(row) {
    row.querySelectorAll("textarea[id]").forEach(field => {
      const editor = window.tinymce?.get(field.id)
      if (!editor) return

      editor.save()
      editor.remove()
    })
  }

  // Each field knows everything about its own name except which row it is in.
  reindex() {
    this.rowTargets.forEach((row, index) => {
      row.querySelectorAll("[data-name-prefix]").forEach(field => {
        field.name = `${field.dataset.namePrefix}[${index}]${field.dataset.nameSuffix}`
      })

      row.querySelector("[data-action*='moveUp']")?.toggleAttribute("disabled", index === 0)
      row.querySelector("[data-action*='moveDown']")
        ?.toggleAttribute("disabled", index === this.rowTargets.length - 1)
    })

    if (this.hasCountTarget) {
      this.countTarget.textContent = ` · ${this.rowTargets.length}`
    }
  }
}

// Kept in step with StructuredRowsHelper::ROW_INDEX.
const PLACEHOLDER = "__INDEX__"
