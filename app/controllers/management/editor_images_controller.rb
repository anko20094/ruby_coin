# frozen_string_literal: true

module Management
  # Where the editor's image button puts a file.
  #
  # The body is Action Text, so an image inside it is an Active Storage blob and the article
  # holds its URL. TinyMCE uploads over XHR and expects one thing back — `location` — which
  # it then writes into the <img src> it inserts.
  class EditorImagesController < ApplicationController
    MAX_BYTES = 8.megabytes
    CONTENT_TYPES = %w[image/jpeg image/png image/gif image/webp image/avif image/svg+xml].freeze

    # The longest edge a body image is served at. A phone camera hands over 2208×2944 and the
    # measure it lands in is 760px wide — shipping the original means every reader downloads
    # several megabytes to look at something 760px across. Twice the measure covers a 2×
    # screen; the original stays in storage untouched.
    MAX_EDGE = 1600

    # A variant of an SVG is not a thing, and a variant of a GIF is its first frame. Both are
    # served as they arrived.
    UNRESIZABLE = %w[image/svg+xml image/gif].freeze

    def create
      authorize [:management, :editor_image], policy_class: Management::EditorImagePolicy

      file = params[:file]
      error = rejection(file)
      return render json: { error: error }, status: :unprocessable_content if error

      blob = ActiveStorage::Blob.create_and_upload!(
        io: file.tempfile, filename: file.original_filename, content_type: file.content_type
      )

      render json: { location: location_for(blob) }, status: :created
    end

    private

    def location_for(blob)
      return rails_blob_path(blob, only_path: true) if UNRESIZABLE.include?(blob.content_type)

      # `quality` and `strip` as top-level transformations, not inside `saver:` — Active
      # Storage validates transformation names against its own allow list and `saver` is not
      # on it. strip also means a body photo cannot carry the camera's GPS onto a public page.
      variant = blob.variant(resize_to_limit: [MAX_EDGE, MAX_EDGE], quality: 82, strip: true).processed

      rails_representation_path(variant, only_path: true)
    rescue StandardError => e
      # A file the processor cannot read is still a file the author uploaded. Serve it whole
      # rather than failing the insert; the log says what happened.
      Rails.logger.warn("[editor_images] variant failed for blob #{blob.id}: #{e.message}")
      rails_blob_path(blob, only_path: true)
    end

    # An upload endpoint that any signed-in editor can reach is a place to park files, so it
    # checks the two things that matter before anything touches disk: what it is, and how big.
    def rejection(file)
      return t('.missing') unless file.respond_to?(:tempfile)
      return t('.type') unless CONTENT_TYPES.include?(file.content_type)
      return t('.size', limit: MAX_BYTES / 1.megabyte) if file.size > MAX_BYTES

      nil
    end
  end
end
