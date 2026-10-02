import { postJSON } from "../../lib/http"

// The code / callout / embed journal blocks, as a toolbar menu button. Each opens a dialog,
// mints the block on the server and drops the returned attachment into the body.
const BLOCK_KINDS = ["code", "callout", "embed"]

// The dialog fields, per kind — the same three shapes the server validates in JournalBlock.
const BLOCK_FIELDS = {
  code: label => [
    { type: "input", name: "language", label: label("language"), placeholder: "ruby" },
    { type: "textarea", name: "source", label: label("source"), maximized: true },
  ],
  callout: label => [
    {
      type: "selectbox",
      name: "tone",
      label: label("tone"),
      items: [
        { text: label("tone_note"), value: "note" },
        { text: label("tone_warn"), value: "warn" },
      ],
    },
    { type: "textarea", name: "body", label: label("body") },
  ],
  embed: label => [
    { type: "input", name: "url", label: label("url"), placeholder: "https://" },
    { type: "input", name: "caption", label: label("caption") },
  ],
}

export const registerBlockMenu = (editor, { url, label }) => {
  editor.ui.registry.addMenuButton("jblock", {
    icon: "code-sample",
    tooltip: label("blocks"),
    fetch: callback =>
      callback(
        BLOCK_KINDS.map(kind => ({
          type: "menuitem",
          text: label(kind),
          onAction: () => openBlockDialog(editor, kind, { url, label }),
        }))
      ),
  })
}

const openBlockDialog = (editor, kind, options) => {
  const { label } = options

  editor.windowManager.open({
    title: label(kind),
    body: { type: "panel", items: BLOCK_FIELDS[kind](label) },
    buttons: [
      { type: "cancel", text: label("cancel") },
      { type: "submit", text: label("insert"), primary: true },
    ],
    onSubmit: dialog => insertBlock(editor, dialog, kind, options),
  })
}

const insertBlock = (editor, dialog, kind, { url, label }) => {
  postJSON(url, { kind, payload: dialog.getData() })
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
      editor.notificationManager.open({ text: label("block_error"), type: "error" })
    })
}

const escapeAttribute = value => String(value).replace(/"/g, "&quot;")
