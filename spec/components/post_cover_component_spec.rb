# frozen_string_literal: true

require 'rails_helper'

describe PostCoverComponent, type: :component do
  include_context 'when carrierwave cleanup'

  it 'shows the cover when the post has one' do
    post = create(:post)

    render_inline(described_class.new(post:, uid: 'spec'))

    expect(page).to have_css("img[src='#{post.photo.small.url}'][alt=''][loading='lazy']")
    expect(page).to have_no_css('svg.rc-gem')
  end

  it 'takes the version it is asked for' do
    post = create(:post)

    render_inline(described_class.new(post:, uid: 'spec', version: :medium))

    expect(page).to have_css("img[src='#{post.photo.medium.url}'][width='#{PhotoUploader::MEDIUM.first}']")
  end

  # The empty grey box this replaces read as a picture that had failed to load. A cover is
  # required, so this is the post whose file has gone missing.
  it 'draws the stone in the post’s own shade where there is no cover' do
    post = create(:post).tap { |record| record.update_columns(photo: nil) }.reload

    cover = render_inline(described_class.new(post:, uid: 'spec'))
    stone = render_inline(GemComponent.new(uid: 'cover-spec', variant: :badge, tone: post.id))

    expect(cover.css('img')).to be_empty
    expect(cover.css('.rc-cover-gem svg.rc-gem--badge[data-controller="ruby"]')).to be_present
    expect(cover.css('stop').pluck('stop-color')).to eq(stone.css('stop').pluck('stop-color'))
  end

  it 'gives the same post the same shade every time' do
    post = create(:post).tap { |record| record.update_columns(photo: nil) }.reload

    first = render_inline(described_class.new(post:, uid: 'a')).css('stop').pluck('stop-color')
    second = render_inline(described_class.new(post:, uid: 'b')).css('stop').pluck('stop-color')

    expect(first).to eq(second)
  end

  it 'refuses a version the uploader does not cut' do
    expect { described_class.new(post: build(:post), uid: 'x', version: :huge) }.to raise_error(ArgumentError)
  end
end
