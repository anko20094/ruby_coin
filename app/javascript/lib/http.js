// The two things every same-origin write from the admin needs.

// null on a page without csrf_meta_tags (the public theme leaves it out on purpose).
export const csrfToken = () =>
  document.querySelector("meta[name=csrf-token]")?.getAttribute("content") ?? null

const withToken = (headers = {}) => {
  const token = csrfToken()
  return token ? { "X-CSRF-Token": token, ...headers } : headers
}

// A JSON request. Resolves with the response itself, so callers can read status before body.
export const postJSON = (url, payload, { method = "POST" } = {}) =>
  fetch(url, {
    method,
    headers: withToken({ "Content-Type": "application/json", Accept: "application/json" }),
    body: JSON.stringify(payload),
  })

// A multipart request (FormData), for forms that carry files.
export const sendForm = (url, body, { method = "POST" } = {}) =>
  fetch(url, { method, headers: withToken({ Accept: "application/json" }), body })
