import { Controller } from "@hotwired/stimulus"
import TomSelect from "tom-select"
import Translations from "../i18n/select"

// Connects to data-controller="tomselect"
export default class extends Controller {

  config = {
    plugins: {
      'remove_button': {
        title: this.i18n['remove_button']
      },
      'no_backspace_delete': { },
      'restore_on_backspace': { }
    },
    valueField: 'id',
    labelField: 'title',
    searchField: 'title',
    create: false,
    load: this.handleLoad.bind(this),
    render: {
      no_results: this.renderNoResults.bind(this)
    },
    onItemAdd: function(value, $item) {
      document.getElementById("post_tag_ids-ts-control") && (document.getElementById("post_tag_ids-ts-control").value = "");
    },
    onItemRemove: function(value, $item) {
      document.getElementById("post_tag_ids-ts-control") && (document.getElementById("post_tag_ids-ts-control").value = "");
    }
    
  }

  connect() {
    this.destroyTomSelect()
    this.select = new TomSelect(this.element, this.config)
  }

  disconnect() {
    if (this.select) {
      this.select.destroy()
    }
  }

  handleLoad(query, callback) {
    const url = `${this.element.dataset.ajaxUrl}.json?term=${encodeURIComponent(query)}`

    fetch(url)
      .then(response => response.json())
      .then(json => {
        callback(json)
      })
      .catch(() => {
        callback()
      })
  }

  renderNoResults(_data, _escape) {
    return `<div class="no-results">${this.i18n['no_results']}</div>`;
  }

  destroyTomSelect() {
    if (this.select) {
      this.select.destroy()
    }
  }

  get i18n() {
    if (!this._i18n) {
      this._i18n = Translations[document.body.dataset.lang]
    }

    return this._i18n
  }
}
