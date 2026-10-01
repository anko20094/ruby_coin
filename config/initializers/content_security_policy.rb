# frozen_string_literal: true

# A real policy. This file was the generated stub with all 27 lines commented out, so no CSP
# header was sent on any response — redesign_plan.md §2 has promised one since the plan was
# written.
#
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
    # its skin inlines a data: image.
    policy.img_src :self, :data, :blob

    # Two directives rather than one: a nonce covers <style> elements, but a style="..."
    # attribute cannot carry one — and the site has them, both server-rendered (the ruby's
    # size) and written by its own controllers (the progress bar, the quote hint).
    policy.style_src_elem :self
    policy.style_src_attr :unsafe_inline

    # Click-to-load embeds (app/javascript/theme/embed_controller.js). Nothing is requested
    # from either host until a reader asks for it; this is the list that lets the frame appear
    # once they do. Noted as a W8 item in redesign_plan.md's W3 loose ends.
    policy.frame_src 'https://www.youtube-nocookie.com', 'https://player.vimeo.com'

    policy.media_src :self
    policy.worker_src :self, :blob
  end

  # No nonce generator, deliberately.
  #
  # The generated stub derives one from the session id, and public pages have no session since
  # the CSRF meta tag left the theme layout — so every response carried a literal `'nonce-'`,
  # which browsers reject as an invalid source and ignore. A random nonce per request would fix
  # that and break something better: the body-digest ETag would change on every response, and
  # conditional GETs are the thing keeping repeat visits cheap on a slow connection.
  #
  # Nothing needs one. The only inline <script> on the site is the JSON-LD block, which is a
  # data block rather than executable code, and every stylesheet and script is self-hosted.
end
