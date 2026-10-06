import { Controller } from "@hotwired/stimulus"
import TomSelect from "tom-select"

export default class extends Controller {
  static values = { url: String, phrases: Object }

  connect() {
    this.select?.destroy()
    this.select = new TomSelect(this.element, this.config())
  }

  disconnect() {
    this.select?.destroy()
    this.select = null
  }

  config() {
    const clearQuery = () => { if (this.select) this.select.control_input.value = "" }

    return {
      plugins: {
        remove_button: { title: this.phrase("remove") },
        no_backspace_delete: {},
        restore_on_backspace: {},
      },
      valueField: "id",
      labelField: "title",
      searchField: "title",
      create: false,
      load: (query, callback) => this.load(query, callback),
      render: {
        no_results: () => {
          const node = document.createElement("div")
          node.className = "no-results"
          node.textContent = this.phrase("no_results")
          return node
        },
      },
      onItemAdd: clearQuery,
      onItemRemove: clearQuery,
    }
  }

  load(query, callback) {
    fetch(`${this.urlValue}.json?term=${encodeURIComponent(query)}`, { headers: { Accept: "application/json" } })
      .then(response => response.json())
      .then(json => callback(json))
      .catch(() => callback())
  }

  phrase(key) {
    return this.phrasesValue[key] || key
  }
}
