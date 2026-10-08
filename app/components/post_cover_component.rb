# frozen_string_literal: true

class PostCoverComponent < ViewComponent::Base
  VERSIONS = { small: PhotoUploader::SMALL, medium: PhotoUploader::MEDIUM }.freeze

  private attr_reader :post, :version, :uid, :loading, :gem_variant

  # uid has to be unique on the page: the same post can be the next entry and a related one.
  # gem_variant: :logo for a copy of the cover that should not come alive (a hover preview of a
  # row that already has a live one).
  def initialize(post:, uid:, version: :small, loading: 'lazy', gem_variant: :badge)
    raise ArgumentError, "version must be one of #{VERSIONS.keys.join(', ')}" unless VERSIONS.key?(version)

    @post = post
    @uid = uid
    @version = version
    @loading = loading
    @gem_variant = gem_variant

    super()
  end

  # CarrierWave reports a cover as absent when its file is missing, so this is also the answer
  # for a cover that was set and has since gone.
  def photo? = post.photo.present?

  def photo_url = post.photo.public_send(version).url
  def width = VERSIONS.fetch(version).first
  def height = VERSIONS.fetch(version).last

  # By id, so a post keeps its shade wherever it is shown and whatever list it is in.
  def tone = post.id.to_i
end
