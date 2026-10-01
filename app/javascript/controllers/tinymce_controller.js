import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="tinymce"
//
// The body editor, on a plain <textarea>. TinyMCE is self-hosted out of public/tinymce (see
// bin/copy_tinymce.mjs) and loads its theme, icons, plugins and skin from there at runtime, so
// it is fetched once, lazily, by the first screen on the page that actually has an editor.
//
// Two profiles:
//
//   post — the full editor: menubar, tables, code samples, images, the lot. What it can make
//          is matched by config/initializers/action_text.rb; anything the toolbar offers
//          survives a save.
//   case — /work case fields. Inline only (forced_root_block is empty), because those strings
//          are printed inside the design's own <p>, <li> and <h3>. A block-level editor there
//          would nest a paragraph inside a list item.
//
// Case forms carry sixty-odd of these fields. Booting sixty editors to type in one is why
// `lazy` exists: the textarea stays a textarea until it is focused.
let loader = null

const loadTinymce = (baseUrl, cacheSuffix) => {
  if (window.tinymce) return Promise.resolve(window.tinymce)
  if (loader) return loader

  loader = new Promise((resolve, reject) => {
    const script = document.createElement("script")
    script.src = `${baseUrl}/tinymce.min.js${cacheSuffix}`
    script.referrerPolicy = "origin"
    script.onload = () => resolve(window.tinymce)
    script.onerror = () => { loader = null; reject(new Error("tinymce failed to load")) }
    document.head.appendChild(script)
  })

  return loader
}

export default class extends Controller {
  static values = {
    profile: { type: String, default: "post" },
    lazy: { type: Boolean, default: false },
    baseUrl: { type: String, default: "/tinymce" },
    cacheSuffix: { type: String, default: "" },
    contentCss: String,
    editorCss: String,
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
    // TinyMCE holding a reference to a dead iframe and the next boot on the same id is a no-op.
    const editor = this.editor
    this.editor = null
    editor?.remove()
  }

  arm() {
    this.element.addEventListener("focus", this.onFirstFocus)
    this.element.classList.add("mg-tinymce-idle")
  }

  // structure_rows removes the editors of a row under controllers that stay connected; each goes
  // back to a textarea that boots on focus. A microtask later: remove() restores the class last.
  released(editor) {
    if (this.editor !== editor) return

    this.editor = null
    if (this.lazyValue) queueMicrotask(() => this.arm())
  }

  // An editor built inside a hidden language tab has nothing to measure and settles at its
  // floor. The tab dispatches this when it shows a group; anything now on screen re-measures.
  revealed = () => {
    if (this.editor?.getContainer()?.offsetParent) {
      this.editor.execCommand("mceAutoResize", false, null, { skip_focus: true })
    }
  }

  // The boot takes as long as the first fetch of TinyMCE; whoever has tabbed on meanwhile is
  // not pulled back.
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
        this.element.insertAdjacentHTML(
          "beforebegin",
          `<p class="mg-field__error">${this.label("load_error")}</p>`
        )
        console.error("[tinymce]", error)
      })
  }

  get isCase() {
    return this.profileValue === "case"
  }

  get language() {
    return this.langValue || this.element.closest("[data-locale]")?.dataset.locale
  }

  // TinyMCE hides the textarea the label points at, so the iframe is named from it. A case
  // field's label carries its language; the post editor's sits inside a language group.
  get accessibleName() {
    const label = this.element.labels?.[0]?.textContent.trim()
    if (!label || this.hasLangValue) return label

    return [label, languageName(this.language)].filter(Boolean).join(" · ")
  }

  settings() {
    return {
      target: this.element,
      base_url: this.baseUrlValue,
      cache_suffix: this.cacheSuffixValue,
      suffix: ".min",
      // TinyMCE 7+ refuses to start without one. `gpl` is the self-hosted open-source build,
      // which is what public/tinymce holds; see its license.md.
      license_key: "gpl",
      promotion: false,
      branding: false,
      skin: "oxide",
      // The editor body reads the real site stylesheet, so what the author sees is the
      // measure, the faces and the ruby rules the article will actually be set in.
      // Two sheets: the real site stylesheet, so the measure, the faces and the ruby rules are
      // the ones the article will be set in — and an editor-only one that puts Prism's token
      // classes on the same palette Rouge uses on the page.
      content_css: [this.contentCssValue, this.editorCssValue].filter(Boolean),
      // The class the public page puts on this text, so theme.css styles the editor's own
      // document the same way: .jn-body for an article, .wk-prose for a case field.
      body_class: this.isCase ? "wk-prose" : "jn-body",
      // theme.css paints the page through body.rc-site, which the editor's document is not.
      content_style: [
        "body { background: var(--paper, #fbfaf8); margin: 16px 20px; }",
        // The top margin of the first block would otherwise leave the caret below the fold.
        "body > :first-child { margin-top: 0; }",
        // Journal blocks are re-rendered from their row on save; in here they are a preview
        // and must read as one thing rather than as text somebody can half-delete.
        "action-text-attachment { display: block; margin: 24px 0; outline: 1px dashed var(--ink-mute, #b9b1ab); outline-offset: 6px; }",
      ].join(" "),
      convert_urls: false,
      relative_urls: false,
      browser_spellcheck: true,
      contextmenu: false,
      ...(this.accessibleName && { iframe_aria_text: this.accessibleName }),
      ...(this.isCase ? this.caseSettings() : this.postSettings()),
      setup: editor => this.setup(editor),
    }
  }

  // One paragraph's worth of inline markup. No root block, no lists, no images: these strings
  // are printed inside markup the case page already owns.
  caseSettings() {
    return {
      // No forced_root_block: "" — TinyMCE 8 removed it. The paragraph the editor wraps its
      // content in never leaves, because `p` is not in valid_elements below: the serialiser
      // drops the tag and keeps the words. Which is the whole requirement — these strings are
      // printed inside markup the case page already owns.
      menubar: false,
      statusbar: false,
      plugins: "autolink autoresize charmap code link searchreplace visualchars wordcount",
      toolbar: "bold italic codeformat | link removeformat | charmap | code | undo redo",
      // A case paragraph is short, but not always; the field grows rather than hiding the end
      // of it behind an inner scrollbar.
      min_height: this.heightValue || 110,
      autoresize_bottom_margin: 12,
      valid_elements: this.validElementsValue,
      formats: INLINE_FORMATS,
      // Enter is a <br>: a second paragraph is one the serialiser drops, which fuses the lines.
      newline_behavior: "linebreak",
      entity_encoding: "raw",
    }
  }

  postSettings() {
    return {
      menubar: "edit view insert format tools table help",
      // The stock Format menu also offers font, size and colours, which are all inline styles.
      menu: {
        format: {
          title: "Format",
          items: "bold italic underline strikethrough superscript subscript codeformat | blocks align | removeformat",
        },
      },
      // Four plugins are deliberately absent, because the sanitiser drops everything they
      // make and a button that loses your work on save is worse than a missing one — see
      // spec/models/action_text_contract_spec.rb, which is what keeps this list honest.
      //
      //   accordion — <details>/<summary>, stripped whole
      //   advlist   — list styles are written as list-style-type, an inline style
      //   media     — <video>/<iframe>, stripped whole; the block menu's Embed is the
      //               supported way, and it is better: click-to-load, and the two hosts it
      //               may reach are named in the CSP
      //   pagebreak — survives as a stray <img class="mce-pagebreak">, which is nothing on a
      //               web page
      plugins: [
        "anchor", "autolink", "autoresize", "charmap", "code",
        "codesample", "directionality", "emoticons", "fullscreen", "help", "image",
        "importcss", "insertdatetime", "link", "lists", "nonbreaking",
        "preview", "searchreplace", "table", "visualblocks", "visualchars", "wordcount",
      ].join(" "),
      toolbar: [
        "undo redo | blocks | bold italic underline strikethrough codeformat | link jblock",
        // No outdent/indent: TinyMCE writes them as an inline padding-left, and `style` is
        // not on the sanitiser's allow list, so the indent vanished on save. Nesting inside a
        // list still works — that produces a real <ul>, and Tab does it.
        "align | bullist numlist | blockquote codesample table image hr",
        "charmap emoticons anchor insertdatetime nonbreaking | removeformat searchreplace",
        "visualblocks code preview fullscreen help",
      ].join(" | "),
      // "wrap", not "sliding". The editor column is 1.3fr of a three-column screen and a
      // sliding toolbar hides most of this behind a "…" — which is exactly the impression the
      // toolbar it replaced gave, and exactly the wrong one. It wraps onto a second row.
      toolbar_mode: "wrap",
      // Grows with the article rather than scrolling inside a fixed box: a listing that runs
      // past the bottom is read by scrolling the page, not by scrolling a pane inside it.
      //
      // No max_height, deliberately — a ceiling just puts the inner scrollbar back a little
      // further down. The preview beside it is sticky, so it stays in view however tall this
      // gets. The reason it was a fixed height before is real and handled: an editor built
      // inside a hidden language tab measures itself at zero and stays there, so the tab tells
      // it to measure again when it is shown. See revealed().
      min_height: this.heightValue || 420,
      autoresize_bottom_margin: 32,
      block_formats: BLOCK_FORMATS.map(([key, tag]) => `${this.label(key)}=${tag}`).join("; "),
      codesample_languages: [
        { text: "Ruby", value: "ruby" },
        { text: "ERB / HTML", value: "markup" },
        { text: "JavaScript", value: "javascript" },
        { text: "CSS", value: "css" },
        { text: "SQL", value: "sql" },
        { text: "Bash", value: "bash" },
        { text: "YAML", value: "yaml" },
      ],
      // Alignment as a class, not a style attribute. config/initializers/action_text.rb says
      // why: `class` survives the sanitiser and `style` is not going on its allow list.
      formats: {
        ...INLINE_FORMATS,
        alignleft: { selector: ALIGNABLE, classes: "align-left" },
        aligncenter: { selector: ALIGNABLE, classes: "align-center" },
        alignright: { selector: ALIGNABLE, classes: "align-right" },
        alignjustify: { selector: ALIGNABLE, classes: "align-justify" },
      },
      // Journal blocks are rows of their own, re-rendered on every page view. They are dropped
      // in as their own element and must survive a round trip through the editor untouched.
      custom_elements: "action-text-attachment",
      extended_valid_elements:
        "action-text-attachment[sgid|content-type|content|url|href|filename|filesize|width|height|previewable|presentation|caption|contenteditable]",
      valid_children: "+body[action-text-attachment],+action-text-attachment[#text|div|figure|pre|p|span|iframe|button|a]",
      noneditable_class: "mce-noneditable",
      images_upload_handler: (blobInfo, progress) => this.upload(blobInfo, progress),
      images_file_types: "jpeg,jpg,png,gif,webp,avif",
      automatic_uploads: true,
      file_picker_types: "image",
    }
  }

  setup(editor) {
    this.registerInlineCode(editor)
    if (this.isCase) this.keepItInline(editor)
    if (!this.isCase && this.hasBlocksUrlValue) this.registerBlockMenu(editor)

    // The screen around this editor listens for `input` on the form — autosave, the dirty
    // badge on each language tab, the save-state line. TinyMCE writes into an iframe, so none
    // of that would ever fire; `editor.save()` puts the HTML back on the textarea and the
    // event tells the form it moved.
    const announce = () => {
      editor.save()
      this.element.dispatchEvent(new Event("input", { bubbles: true }))
    }

    editor.on("change input undo redo", announce)
    editor.on("remove", () => this.released(editor))

    // Belt and braces on the way out: TinyMCE hooks the form's submit itself, but the autosave
    // path builds a FormData by hand and would otherwise read a stale textarea.
    editor.on("init", () => {
      this.element.form?.addEventListener("submit", () => editor.save())
      if (this.language) editor.getDoc().documentElement.lang = this.language
    })
  }

  // TinyMCE ships a `code` toolbar button and it opens the source-code dialog; the inline
  // <code> format is only reachable from the Format menu, which the case profile does not have
  // and which nobody goes looking in. On a site whose prose is about Ruby, that is the wrong
  // button to make people hunt for — ProseHelper::RICH_TAGS lists exactly three tags and this
  // is one of them.
  registerInlineCode(editor) {
    editor.ui.registry.addToggleButton("codeformat", {
      icon: "sourcecode",
      tooltip: this.label("inline_code"),
      onAction: () => editor.execCommand("mceToggleFormat", false, "code"),
      onSetup: api => {
        api.setActive(editor.formatter.match("code"))
        const changed = editor.formatter.formatChanged("code", state => api.setActive(state))
        return () => changed.unbind()
      },
    })
  }

  // TinyMCE 8 removed forced_root_block: "", so there is no longer a way to ask it not to wrap
  // what you type in a paragraph. It still has to come out unwrapped: a case field is printed
  // inside the design's own <p>, <li> or <h3>, and ProseHelper::RICH_TAGS does not include `p`,
  // so a wrapper would be stripped on render anyway — after being stored, and after showing up
  // in every diff. The editor keeps its paragraph; the value that leaves does not have one.
  keepItInline(editor) {
    // Pasted blocks would otherwise lose their boundary with the tag: "alpha" and "beta" fuse.
    editor.on("PastePreProcess", event => {
      event.content = event.content.replace(BLOCK_BOUNDARY, "<br>")
    })

    editor.on("GetContent", event => {
      // 'raw' is TinyMCE talking to itself — undo levels, the internal cache. Only the HTML
      // that is on its way to the textarea gets unwrapped.
      if (event.format !== "html") return

      event.content = event.content
        .replace(/^\s*<p[^>]*>/i, "")
        .replace(/<\/p>\s*$/i, "")
        .trim()
    })
  }

  // The code / callout / embed blocks, as a toolbar button with a menu. This was a slash menu
  // reachable only by typing "/" into the body — a feature nothing on the screen mentioned,
  // which is a fair definition of a feature nobody has.
  registerBlockMenu(editor) {
    editor.ui.registry.addMenuButton("jblock", {
      icon: "code-sample",
      tooltip: this.label("blocks"),
      fetch: callback =>
        callback(
          BLOCK_KINDS.map(kind => ({
            type: "menuitem",
            text: this.label(kind),
            onAction: () => this.openBlockDialog(editor, kind),
          }))
        ),
    })
  }

  openBlockDialog(editor, kind) {
    editor.windowManager.open({
      title: this.label(kind),
      body: { type: "panel", items: BLOCK_FIELDS[kind](this) },
      buttons: [
        { type: "cancel", text: this.label("cancel") },
        { type: "submit", text: this.label("insert"), primary: true },
      ],
      onSubmit: dialog => this.insertBlock(editor, dialog, kind),
    })
  }

  insertBlock(editor, dialog, kind) {
    fetch(this.blocksUrlValue, {
      method: "POST",
      headers: { "X-CSRF-Token": csrfToken(), "Content-Type": "application/json" },
      body: JSON.stringify({ kind, payload: dialog.getData() }),
    })
      .then(response => response.json().then(data => ({ ok: response.ok, data })))
      .then(({ ok, data }) => {
        if (!ok) {
          editor.notificationManager.open({ text: (data.errors || []).join(", "), type: "error" })
          return
        }

        editor.insertContent(
          `<action-text-attachment sgid="${escapeAttribute(data.sgid)}" contenteditable="false">` +
            `${data.content}</action-text-attachment><p><br></p>`
        )
        dialog.close()
      })
      .catch(() => {
        editor.notificationManager.open({ text: this.label("block_error"), type: "error" })
      })
  }

  // TinyMCE's own image upload, pointed at Active Storage. Returns the blob's URL, which is
  // what goes in the <img src> the sanitiser lets through.
  upload(blobInfo, progress) {
    return new Promise((resolve, reject) => {
      const request = new XMLHttpRequest()
      const body = new FormData()
      body.append("file", blobInfo.blob(), blobInfo.filename())

      request.open("POST", this.uploadUrlValue)
      request.setRequestHeader("X-CSRF-Token", csrfToken())
      request.upload.onprogress = event => progress((event.loaded / event.total) * 100)
      request.onerror = () => reject({ message: this.label("upload_error"), remove: true })
      request.onload = () => {
        if (request.status !== 201) return reject({ message: this.uploadError(request), remove: true })

        resolve(JSON.parse(request.responseText).location)
      }
      request.send(body)
    })
  }

  // A refused upload says why, in the admin's language; anything that is not that answer (a proxy's
  // 413, an HTML error page) gets the generic wording.
  uploadError(request) {
    try {
      return JSON.parse(request.responseText).error || this.label("upload_error")
    } catch {
      return this.label("upload_error")
    }
  }

  label(key) {
    return this.labelsValue?.[key] || key
  }
}

// The post editor's language tabs announce a group becoming visible with this.
export const REVEAL_EVENT = "tinymce:reveal"

const ALIGNABLE = "p,h1,h2,h3,h4,h5,h6,td,th,div,ul,ol,li,table,img,pre,blockquote"

// TinyMCE writes underline as a span with an inline style, which the sanitiser strips.
const INLINE_FORMATS = { underline: { inline: "u", exact: true } }
const BLOCK_KINDS = ["code", "callout", "embed"]
const BLOCK_BOUNDARY = /<\/(?:p|div|li|h[1-6])>\s*(?=<(?:p|div|li|h[1-6])[\s>])/gi
const BLOCK_FORMATS = [["paragraph", "p"], ["heading2", "h2"], ["heading3", "h3"], ["heading4", "h4"], ["preformatted", "pre"]]

// The dialog fields, per kind — the same three shapes the server validates in JournalBlock.
const BLOCK_FIELDS = {
  code: controller => [
    { type: "input", name: "language", label: controller.label("language"), placeholder: "ruby" },
    { type: "textarea", name: "source", label: controller.label("source"), maximized: true },
  ],
  callout: controller => [
    {
      type: "selectbox",
      name: "tone",
      label: controller.label("tone"),
      items: [
        { text: controller.label("tone_note"), value: "note" },
        { text: controller.label("tone_warn"), value: "warn" },
      ],
    },
    { type: "textarea", name: "body", label: controller.label("body") },
  ],
  embed: controller => [
    { type: "input", name: "url", label: controller.label("url"), placeholder: "https://" },
    { type: "input", name: "caption", label: controller.label("caption") },
  ],
}

const languageName = code => {
  try {
    return new Intl.DisplayNames([document.documentElement.lang || "en"], { type: "language" }).of(code)
  } catch {
    return code
  }
}

const csrfToken = () =>
  document.querySelector("meta[name=csrf-token]")?.getAttribute("content")

const escapeAttribute = value => String(value).replace(/"/g, "&quot;")
