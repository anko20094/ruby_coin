import { imageUploader } from "./upload"

// The two editor profiles.
//
//   post — the full editor: menubar, tables, code samples, images, the lot. What it can make
//          is matched by config/initializers/action_text.rb; anything the toolbar offers
//          survives a save.
//   case — /work case fields. Inline only, because those strings are printed inside the
//          design's own <p>, <li> and <h3>.

const ALIGNABLE = "p,h1,h2,h3,h4,h5,h6,td,th,div,ul,ol,li,table,img,pre,blockquote"

// TinyMCE writes underline as a span with an inline style, which the sanitiser strips.
export const INLINE_FORMATS = { underline: { inline: "u", exact: true } }
const BLOCK_BOUNDARY = /<\/(?:p|div|li|h[1-6])>\s*(?=<(?:p|div|li|h[1-6])[\s>])/gi
const BLOCK_FORMATS = [["paragraph", "p"], ["heading2", "h2"], ["heading3", "h3"], ["heading4", "h4"], ["preformatted", "pre"]]

// One paragraph's worth of inline markup. No root block, no lists, no images.
export const caseSettings = ({ height, validElements }) => ({
  // TinyMCE 8 removed forced_root_block: "". The paragraph it wraps content in never leaves,
  // because `p` is not in valid_elements: the serialiser drops the tag and keeps the words.
  menubar: false,
  statusbar: false,
  plugins: "autolink autoresize charmap code link searchreplace visualchars wordcount",
  toolbar: "bold italic codeformat | link removeformat | charmap | code | undo redo",
  // Grows rather than hiding the end of a long paragraph behind an inner scrollbar.
  min_height: height || 110,
  autoresize_bottom_margin: 12,
  valid_elements: validElements,
  formats: INLINE_FORMATS,
  // Enter is a <br>: a second paragraph is one the serialiser drops, which fuses the lines.
  newline_behavior: "linebreak",
  entity_encoding: "raw",
})

export const postSettings = ({ height, label, uploadUrl }) => ({
  menubar: "edit view insert format tools table help",
  // The stock Format menu also offers font, size and colours, which are all inline styles.
  menu: {
    format: {
      title: "Format",
      items: "bold italic underline strikethrough superscript subscript codeformat | blocks align | removeformat",
    },
  },
  // Four plugins are deliberately absent, because the sanitiser drops everything they make —
  // spec/models/action_text_contract_spec.rb keeps this list honest.
  //
  //   accordion — <details>/<summary>, stripped whole
  //   advlist   — list styles are written as list-style-type, an inline style
  //   media     — <video>/<iframe>, stripped whole; the block menu's Embed is the supported way
  //   pagebreak — survives as a stray <img class="mce-pagebreak">
  //
  // preview is absent too: its dialog is an iframe srcdoc with an inline <script> and <style>,
  // which the CSP blocks. The editor screen has its own preview pane, rendering the real page.
  plugins: [
    "anchor", "autolink", "autoresize", "charmap", "code",
    "codesample", "directionality", "emoticons", "fullscreen", "help", "image",
    "importcss", "insertdatetime", "link", "lists", "nonbreaking",
    "searchreplace", "table", "visualblocks", "visualchars", "wordcount",
  ].join(" "),
  toolbar: [
    "undo redo | blocks | bold italic underline strikethrough codeformat | link jblock",
    // No outdent/indent: TinyMCE writes them as inline padding, which the sanitiser strips.
    "align | bullist numlist | blockquote codesample table image hr",
    "charmap emoticons anchor insertdatetime nonbreaking | removeformat searchreplace",
    "visualblocks code fullscreen help",
  ].join(" | "),
  // "wrap", not "sliding": a sliding toolbar hides most of this behind a "…".
  toolbar_mode: "wrap",
  // Grows with the article; no max_height, which would only bring the inner scrollbar back.
  // An editor built inside a hidden tab re-measures on REVEAL_EVENT.
  min_height: height || 420,
  autoresize_bottom_margin: 32,
  block_formats: BLOCK_FORMATS.map(([key, tag]) => `${label(key)}=${tag}`).join("; "),
  codesample_languages: [
    { text: "Ruby", value: "ruby" },
    { text: "ERB / HTML", value: "markup" },
    { text: "JavaScript", value: "javascript" },
    { text: "CSS", value: "css" },
    { text: "SQL", value: "sql" },
    { text: "Bash", value: "bash" },
    { text: "YAML", value: "yaml" },
  ],
  // Alignment as a class, not a style attribute: `class` survives the sanitiser.
  formats: {
    ...INLINE_FORMATS,
    alignleft: { selector: ALIGNABLE, classes: "align-left" },
    aligncenter: { selector: ALIGNABLE, classes: "align-center" },
    alignright: { selector: ALIGNABLE, classes: "align-right" },
    alignjustify: { selector: ALIGNABLE, classes: "align-justify" },
  },
  // Journal blocks are rows of their own, re-rendered on every page view, and must survive a
  // round trip through the editor untouched.
  custom_elements: "action-text-attachment",
  extended_valid_elements:
    "action-text-attachment[sgid|content-type|content|url|href|filename|filesize|width|height|previewable|presentation|caption|contenteditable]",
  valid_children: "+body[action-text-attachment],+action-text-attachment[#text|div|figure|pre|p|span|iframe|button|a]",
  noneditable_class: "mce-noneditable",
  images_upload_handler: imageUploader(uploadUrl, label),
  images_file_types: "jpeg,jpg,png,gif,webp,avif",
  automatic_uploads: true,
  file_picker_types: "image",
})

// The inline <code> format as a toolbar button. TinyMCE's own `code` button opens the source
// dialog; on a site about Ruby, inline code should not hide in the Format menu.
export const registerInlineCode = (editor, label) => {
  editor.ui.registry.addToggleButton("codeformat", {
    icon: "sourcecode",
    tooltip: label("inline_code"),
    onAction: () => editor.execCommand("mceToggleFormat", false, "code"),
    onSetup: api => {
      api.setActive(editor.formatter.match("code"))
      const changed = editor.formatter.formatChanged("code", state => api.setActive(state))
      return () => changed.unbind()
    },
  })
}

// A case field is printed inside the design's own markup, so the value that leaves the editor
// must not carry the paragraph TinyMCE 8 insists on wrapping it in.
export const keepItInline = editor => {
  // Pasted blocks would otherwise lose their boundary: "alpha" and "beta" fuse.
  editor.on("PastePreProcess", event => {
    event.content = event.content.replace(BLOCK_BOUNDARY, "<br>")
  })

  editor.on("GetContent", event => {
    // 'raw' is TinyMCE talking to itself (undo levels); only HTML bound for the textarea.
    if (event.format !== "html") return

    event.content = event.content
      .replace(/^\s*<p[^>]*>/i, "")
      .replace(/<\/p>\s*$/i, "")
      .trim()
  })
}
