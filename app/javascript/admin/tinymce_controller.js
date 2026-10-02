import { Controller } from "@hotwired/stimulus"
import { loadTinymce, REVEAL_EVENT } from "./tinymce/loader"
import { caseSettings, postSettings, registerInlineCode, keepItInline } from "./tinymce/profiles"
import { registerBlockMenu } from "./tinymce/blocks"

// Connects to data-controller="tinymce"
//
// The body editor, on a plain <textarea>. Profiles live in ./tinymce/profiles.js; this
// controller only boots, wires and tears down. Case forms carry sixty-odd of these fields,
// which is why `lazy` exists: the textarea stays a textarea until it is focused.
export default class extends Controller {
  static values = {
    profile: { type: String, default: "post" },
    lazy: { type: Boolean, default: false },
    baseUrl: { type: String, default: "/tinymce" },
    cacheSuffix: { type: String, default: "" },
    contentCss: String,
    blocksUrl: String,
    uploadUrl: String,
    validElements: String,
    lang: String,
    height: { type: Number, default: 0 },
    labels: Object,
  }

  connect() {
    this.editor = null
    document.addEventListener(REVEAL_EVENT, this.revealed)

    if (this.lazyValue) {
      this.arm()
    } else {
      this.boot()
    }
  }

  disconnect() {
    document.removeEventListener(REVEAL_EVENT, this.revealed)
    this.element.removeEventListener("focus", this.onFirstFocus)
    // remove(), not destroy(): destroy() on a node Stimulus has already detached leaves
    // TinyMCE holding a dead iframe, and the next boot on the same id is a no-op.
    const editor = this.editor
    this.editor = null
    editor?.remove()
  }

  arm() {
    this.element.addEventListener("focus", this.onFirstFocus)
    this.element.classList.add("mg-tinymce-idle")
  }

  // structure_rows removes a row's editors under controllers that stay connected; each goes back
  // to a textarea that boots on focus. A microtask later: remove() restores the class last.
  released(editor) {
    if (this.editor !== editor) return

    this.editor = null
    if (this.lazyValue) queueMicrotask(() => this.arm())
  }

  // An editor built inside a hidden language tab has nothing to measure and settles at its floor.
  revealed = () => {
    if (this.editor?.getContainer()?.offsetParent) {
      this.editor.execCommand("mceAutoResize", false, null, { skip_focus: true })
    }
  }

  // Whoever has tabbed on while TinyMCE was loading is not pulled back.
  onFirstFocus = () => {
    this.element.removeEventListener("focus", this.onFirstFocus)
    this.element.classList.remove("mg-tinymce-idle")
    this.boot().then(() => {
      if ([this.element, document.body].includes(document.activeElement)) this.editor?.focus()
    })
  }

  boot() {
    return loadTinymce(this.baseUrlValue, this.cacheSuffixValue)
      .then(tinymce => tinymce.init(this.settings()))
      .then(([editor]) => { this.editor = editor })
      .catch(error => {
        // A textarea that still holds the body is a working fallback. Silence would not be.
        this.element.classList.remove("mg-tinymce-idle")
        const note = document.createElement("p")
        note.className = "mg-field__error"
        note.textContent = this.label("load_error")
        this.element.before(note)
        console.error("[tinymce]", error)
      })
  }

  get isCase() {
    return this.profileValue === "case"
  }

  get language() {
    return this.langValue || this.element.closest("[data-locale]")?.dataset.locale
  }

  // TinyMCE hides the textarea the label points at, so the iframe is named from it.
  get accessibleName() {
    const label = this.element.labels?.[0]?.textContent.trim()
    if (!label || this.hasLangValue) return label

    return [label, languageName(this.language)].filter(Boolean).join(" · ")
  }

  settings() {
    const label = key => this.label(key)
    const profile = this.isCase
      ? caseSettings({ height: this.heightValue, validElements: this.validElementsValue })
      : postSettings({ height: this.heightValue, label, uploadUrl: this.uploadUrlValue })

    return {
      target: this.element,
      base_url: this.baseUrlValue,
      cache_suffix: this.cacheSuffixValue,
      suffix: ".min",
      // TinyMCE 7+ refuses to start without one; `gpl` is the self-hosted open-source build.
      license_key: "gpl",
      promotion: false,
      branding: false,
      skin: "oxide",
      // editor_content.css: the site's tokens, faces and article rules in one sheet.
      content_css: [this.contentCssValue].filter(Boolean),
      // The class the public page puts on this text: .jn-body for an article, .wk-prose for a case.
      body_class: this.isCase ? "wk-prose" : "jn-body",
      content_style: [
        "body { background: var(--paper, #fbfaf8); margin: 16px 20px; }",
        // The first block's top margin would otherwise leave the caret below the fold.
        "body > :first-child { margin-top: 0; }",
        // Journal blocks are a preview in here and must read as one object.
        "action-text-attachment { display: block; margin: 24px 0; outline: 1px dashed var(--ink-mute, #b9b1ab); outline-offset: 6px; }",
      ].join(" "),
      convert_urls: false,
      relative_urls: false,
      browser_spellcheck: true,
      contextmenu: false,
      ...(this.accessibleName && { iframe_aria_text: this.accessibleName }),
      ...profile,
      setup: editor => this.setup(editor),
    }
  }

  setup(editor) {
    const label = key => this.label(key)
    registerInlineCode(editor, label)
    if (this.isCase) keepItInline(editor)
    if (!this.isCase && this.hasBlocksUrlValue) registerBlockMenu(editor, { url: this.blocksUrlValue, label })

    // The form listens for `input` (autosave, dirty badges, the unsaved guard). TinyMCE writes
    // into an iframe, so the HTML is saved back to the textarea and the event raised by hand.
    const announce = () => {
      editor.save()
      this.element.dispatchEvent(new Event("input", { bubbles: true }))
    }

    editor.on("change input undo redo", announce)
    editor.on("remove", () => this.released(editor))

    // The autosave builds a FormData by hand and would otherwise read a stale textarea.
    editor.on("init", () => {
      this.element.form?.addEventListener("submit", () => editor.save())
      if (this.language) editor.getDoc().documentElement.lang = this.language
    })
  }

  label(key) {
    return this.labelsValue?.[key] || key
  }
}

const languageName = code => {
  try {
    return new Intl.DisplayNames([document.documentElement.lang || "en"], { type: "language" }).of(code)
  } catch {
    return code
  }
}
