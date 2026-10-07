import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["rows", "template", "count", "row", "add"]
  static values = { next: Number }

  connect() {
    this.reindex()
  }

  add() {
    const uid = this.nextValue
    this.nextValue = uid + 1

    this.rowsTarget.insertAdjacentHTML("beforeend", this.templateTarget.innerHTML.replaceAll(PLACEHOLDER, uid))
    this.reindex()
    this.changed()

    const added = this.rowTargets[this.rowTargets.length - 1]
    added?.querySelector("input, textarea")?.focus()
    const reduced = matchMedia("(prefers-reduced-motion: reduce)").matches
    added?.scrollIntoView({ block: "nearest", behavior: reduced ? "auto" : "smooth" })
  }

  remove(event) {
    const row = event.currentTarget.closest("[data-structure-rows-target='row']")
    if (!row) return

    const index = this.rowTargets.indexOf(row)

    // The editors inside go first. Stimulus would disconnect them a microtask later anyway,
    // but by then TinyMCE is holding an iframe whose document has already been detached.
    this.destroyEditorsIn(row)
    row.remove()
    this.reindex()
    this.changed()

    const next = this.rowTargets[index] || this.rowTargets[index - 1]
    const target = next?.querySelector("input, textarea") || (this.hasAddTarget && this.addTarget)
    target?.focus()
  }

  moveUp(event) {
    const row = event.currentTarget.closest("[data-structure-rows-target='row']")
    this.swap(row, row?.previousElementSibling)
    this.refocus(row, event.currentTarget)
  }

  moveDown(event) {
    const row = event.currentTarget.closest("[data-structure-rows-target='row']")
    this.swap(row?.nextElementSibling, row)
    this.refocus(row, event.currentTarget)
  }

  // A moved node drops focus, and the pressed button is disabled when its row has reached an end.
  refocus(row, button) {
    const control = button.disabled ? row.querySelector("[data-action*='structure-rows#move']:not([disabled])") : button
    control?.focus()
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
    this.changed()
  }

  // Rows are form content too: whatever listens for input on the form should hear about them.
  changed() {
    this.element.dispatchEvent(new Event("input", { bubbles: true }))
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

      const name = row.querySelector(".mg-row__name")
      if (name) name.textContent = `${name.dataset.label} ${index + 1}`

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
