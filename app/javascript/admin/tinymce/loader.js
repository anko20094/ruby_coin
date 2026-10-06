// TinyMCE is self-hosted out of public/tinymce (see bin/copy_tinymce.mjs) and loads its theme,
// icons, plugins and skin from there at runtime. The script is fetched once, lazily, by the
// first editor on the page.
let loader = null

export const loadTinymce = (baseUrl, cacheSuffix) => {
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

// The post editor's language tabs announce a group becoming visible with this.
export const REVEAL_EVENT = "tinymce:reveal"
