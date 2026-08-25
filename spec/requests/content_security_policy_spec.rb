# frozen_string_literal: true

require 'rails_helper'

# The initializer was the generated stub with all 27 lines commented out, so no policy header
# was sent on any response.
describe 'content security policy', type: :request do
  def policy
    response.headers['Content-Security-Policy'].to_s
  end

  it 'sends one at all' do
    get '/en/journal'

    expect(policy).to be_present
  end

  it 'allows scripts and stylesheets from this origin only' do
    get '/en/journal'

    expect(policy).to include("script-src 'self'")
    expect(policy).to include("style-src-elem 'self'")
    expect(policy).not_to include("script-src 'self' 'unsafe-inline'")
  end

  # A style attribute cannot carry a nonce, and the site has them — the ruby's size is
  # server-rendered, the progress bar and the quote hint are written by their controllers.
  it 'allows style attributes, which are the only inline styling the site uses' do
    get '/en/journal'

    expect(policy).to include("style-src-attr 'unsafe-inline'")
  end

  # Nothing is requested from either host until a reader clicks an embed; this is what lets the
  # frame appear when they do. Listed as a W3 loose end in redesign_plan.md.
  it 'lets a clicked embed load, and nothing else frame the page' do
    get '/en/journal'

    expect(policy).to include('frame-src https://www.youtube-nocookie.com https://player.vimeo.com')
    expect(policy).to include("frame-ancestors 'self'")
    expect(policy).to include("object-src 'none'")
  end

  it 'never emits an empty nonce, which browsers discard along with the directive' do
    get '/en/journal'

    expect(policy).not_to include("'nonce-'")
  end

  # TinyMCE writes its skin into the page as inline <style> elements as the editor builds
  # itself and offers no way to turn that off. Relaxed for the admin only, which is behind a
  # password.
  it 'gives the admin the one exception it needs, and the public site none' do
    sign_in create(:user, role: :admin)
    get '/en/management/posts'
    expect(policy).to include("style-src-elem 'self' 'unsafe-inline'")

    get '/en/journal'
    expect(policy).to include("style-src-elem 'self'")
    expect(policy).not_to include("style-src-elem 'self' 'unsafe-inline'")
  end

  # The other half of the same override, and it goes the other way. The public policy names two
  # video hosts because a reader can click an embed open; nothing under /management does, and
  # the editor only ever frames its own document.
  it 'narrows frame-src in the admin rather than widening it' do
    sign_in create(:user, role: :admin)
    get '/en/management/posts'

    expect(policy).to include("frame-src 'self'")
    expect(policy).not_to include('youtube-nocookie')
  end

  # TinyMCE is served out of public/tinymce — same origin, so script-src 'self' covers it and
  # the editor needs no exception of its own. This is the assertion that fails if it is ever
  # swapped for the Tiny Cloud CDN.
  it 'keeps script-src at self on both sides, editor included' do
    sign_in create(:user, role: :admin)
    get '/en/management/posts/new'
    expect(policy).to include("script-src 'self'")
    expect(response.body).to include('data-tinymce-base-url-value="/tinymce"')
  end
end
