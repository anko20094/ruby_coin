import { csrfToken } from "../../lib/http"

// TinyMCE's image upload, pointed at Active Storage. Resolves with the blob's URL, which is what
// goes in the <img src> the sanitiser lets through. XHR rather than fetch: TinyMCE wants progress.
export const imageUploader = (url, label) => (blobInfo, progress) =>
  new Promise((resolve, reject) => {
    const request = new XMLHttpRequest()
    const body = new FormData()
    body.append("file", blobInfo.blob(), blobInfo.filename())

    request.open("POST", url)
    const token = csrfToken()
    if (token) request.setRequestHeader("X-CSRF-Token", token)
    request.upload.onprogress = event => progress((event.loaded / event.total) * 100)
    request.onerror = () => reject({ message: label("upload_error"), remove: true })
    request.onload = () => {
      if (request.status !== 201) return reject({ message: uploadError(request, label), remove: true })

      resolve(JSON.parse(request.responseText).location)
    }
    request.send(body)
  })

// A refused upload says why, in the admin's language; anything that is not that answer (a
// proxy's 413, an HTML error page) gets the generic wording.
const uploadError = (request, label) => {
  try {
    return JSON.parse(request.responseText).error || label("upload_error")
  } catch {
    return label("upload_error")
  }
}
