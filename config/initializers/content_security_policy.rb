# frozen_string_literal: true

# The site is unusually easy to lock down: every script and stylesheet is self-hosted, the
# fonts are in the repo, and there is no third-party analytics. The two exceptions are both
# deliberate and both narrow.
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.base_uri    :self
    policy.object_src  :none
    policy.form_action :self
    policy.frame_ancestors :self

    policy.font_src :self
    policy.script_src :self
    policy.connect_src :self

    # TinyMCE shows a pasted or dropped image from a blob: URL until its upload answers, and
    # its skin inlines a data: image. `https:` for the bodies the old TinyMCE wrote: it inserted
    # images by their external address, and the move to Action Text kept those <img src>. An
    # image cannot run anything, so this widens what a page may show, not what it may do.
    # Plain http: stays out — a browser blocks it on an https page as mixed content anyway.
    policy.img_src :self, :https, :data, :blob

    # Two directives rather than one: a nonce covers <style> elements, but a style="..."
    # attribute cannot carry one — and the site has them, both server-rendered (the ruby's
    # size) and written by its own controllers (the progress bar, the quote hint).
    policy.style_src_elem :self
    policy.style_src_attr :unsafe_inline

    # Click-to-load embeds (app/javascript/theme/embed_controller.js). Nothing is requested
    # from either host until a reader asks for it; this is the list that lets the frame appear
    # once they do.
    policy.frame_src 'https://www.youtube-nocookie.com', 'https://player.vimeo.com'

    policy.media_src :self
    policy.worker_src :self, :blob
  end

  # No nonce generator, deliberately: public pages have no session to derive one from, and a
  # random nonce per request would break the body-digest ETags that keep repeat visits cheap.
  # Nothing needs one — the only inline <script> is JSON-LD, a data block, not code.
end
