# frozen_string_literal: true

module Management
  # Every screen under /management is behind the same door, and the door is here rather than
  # repeated in each controller: a controller that forgets the line is the failure this class
  # exists to prevent — #translate forgot it, and left an OpenAI endpoint open to the world.
  #
  # verify_authorized is the second half of the same guarantee: authentication says who you
  # are, and this says an action that never asked Pundit is a bug, not a public action.
  class ApplicationController < ApplicationController
    layout 'management/layouts/application'

    before_action :forbid_indexing
    before_action :authenticate_user!
    after_action :verify_authorized

    # The one place the site-wide policy has to give. TinyMCE writes its skin into the page as
    # inline <style> elements as the editor builds itself, and offers no way to turn that off —
    # a style element cannot carry a nonce it was never given, and hashing them would break on
    # every TinyMCE release. Relaxed here and only here: these screens are behind a password,
    # and the public site keeps `style-src-elem 'self'` with no exceptions.
    #
    # frame-src is narrowed rather than relaxed. The site-wide policy names two video hosts,
    # because a reader can click an embed open; nothing under /management does, and the editor
    # only ever frames its own srcdoc document.
    content_security_policy do |policy|
      policy.style_src_elem :self, :unsafe_inline
      policy.frame_src :self
    end
  end
end
