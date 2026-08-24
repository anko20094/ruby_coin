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

    before_action :authenticate_user!
    after_action :verify_authorized

    # The one place the site-wide policy has to give. Trix appends its default stylesheet as an
    # inline <style> element when it loads, and offers no way to turn that off — a style
    # element cannot carry a nonce it was never given, and hashing it would break on every Trix
    # release. Relaxed here and only here: these screens are behind a password, and the public
    # site keeps `style-src-elem 'self'` with no exceptions.
    content_security_policy do |policy|
      policy.style_src_elem :self, :unsafe_inline
    end
  end
end
