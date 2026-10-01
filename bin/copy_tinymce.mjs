#!/usr/bin/env node
// Self-hosted TinyMCE.
//
// TinyMCE loads its theme, model, icons, plugins and skins at runtime from `base_url` rather
// than from the bundle, so esbuild cannot help here — the files have to exist under a URL the
// browser can fetch. They go to public/tinymce/, which is same-origin, so the admin's CSP
// (script-src 'self') needs no exception for them.
//
// Only what the editor actually asks for is copied: the GPL plugins named in
// app/javascript/controllers/tinymce_controller.js, two UI skins, two content skins. Copying
// node_modules/tinymce whole would put 13 MB of languages and unused skins into public/.
import { cp, mkdir, rm, writeFile } from "node:fs/promises"
import { createRequire } from "node:module"
import path from "node:path"

const require = createRequire(import.meta.url)
const source = path.dirname(require.resolve("tinymce/package.json"))
const version = require("tinymce/package.json").version
const target = path.resolve("public/tinymce")

// Keep in step with `plugins:` in tinymce_controller.js. A plugin named there and missing
// here fails at runtime with a 404 and a silently reduced toolbar, so the list is asserted
// against the controller by spec/javascript/tinymce_assets_spec.rb.
const PLUGINS = [
  "anchor", "autolink", "autoresize", "charmap", "code",
  "codesample",
  "directionality", "emoticons", "fullscreen", "help", "image", "importcss",
  "insertdatetime", "link", "lists", "nonbreaking", "preview", "searchreplace", "table",
  "visualblocks", "visualchars", "wordcount",
]

const UI_SKINS = ["oxide", "oxide-dark"]
const CONTENT_SKINS = ["default", "dark", "document", "writer"]

// Only the minified build. Every directory here ships plugin.js, plugin.min.js and a .ts
// source map beside each other; taking all three put 8.3 MB into public/ to serve 2.3 MB.
const MINIFIED = /(\.min\.(js|css)|tinymce\.min\.js|license\.md)$/
// Runtime data a plugin fetches by name rather than importing: the help plugin's keyboard-
// navigation strings, the emoji list. There is no minified twin to take instead, and the help
// dialog asks for one by locale and logs a 404 when it is not there.
const RUNTIME_DATA = /[\\/]js[\\/]/

const copy = (from, to) =>
  cp(path.join(source, from), path.join(target, to), {
    recursive: true,
    filter: (entry) => !path.extname(entry) || MINIFIED.test(entry) || RUNTIME_DATA.test(entry),
  })

await rm(target, { recursive: true, force: true })
await mkdir(target, { recursive: true })

await copy("tinymce.min.js", "tinymce.min.js")
await copy("license.md", "license.md")
await copy("models/dom", "models/dom")
await copy("themes/silver", "themes/silver")
await copy("icons/default", "icons/default")

await Promise.all(PLUGINS.map((plugin) => copy(`plugins/${plugin}`, `plugins/${plugin}`)))
await Promise.all(UI_SKINS.map((skin) => copy(`skins/ui/${skin}`, `skins/ui/${skin}`)))
await Promise.all(CONTENT_SKINS.map((skin) => copy(`skins/content/${skin}`, `skins/content/${skin}`)))

// The controller reads this to build a cache-busting base_url, so a TinyMCE upgrade is not
// served from a stale browser cache of public/tinymce.
await writeFile(path.join(target, "VERSION"), `${version}\n`)

console.log(`tinymce ${version} → public/tinymce`)
