# frozen_string_literal: true

module Management
  # Where the editor's image button puts a file.
  #
  # The body is Action Text, so an image inside it is an Active Storage blob and the article
  # holds its URL. TinyMCE uploads over XHR and expects one thing back — `location` — which
  # it then writes into the <img src> it inserts.
  class EditorImagesController < ApplicationController
    MAX_BYTES = 8.megabytes

    # What the bytes may be, and the extension each is stored under. SVG is not here: Active
    # Storage serves it as a download, so an <img> pointing at it is broken.
    FORMATS = {
      'image/jpeg' => 'jpg', 'image/png' => 'png', 'image/gif' => 'gif', 'image/webp' => 'webp', 'image/avif' => 'avif'
    }.freeze

    # The longest edge a stored body image keeps. A phone camera hands over 2208×2944 and the
    # measure it lands in is 760px wide; twice that covers a 2× screen.
    MAX_EDGE = 1600

    def create
      authorize [:management, :editor_image], policy_class: Management::EditorImagePolicy

      file = params[:file]
      error = rejection(file)
      return render json: { error: error }, status: :unprocessable_content if error

      render json: { location: rails_blob_path(clean_blob(file), only_path: true) }, status: :created
    rescue ImageProcessing::Error, ::MiniMagick::Error => e
      Rails.logger.warn("[editor_images] could not process #{file.original_filename}: #{e.message}")
      render json: { error: t('.processing') }, status: :unprocessable_content
    end

    private

    # The stored blob is the cleaned file, never the upload: it is what a signed blob URL
    # serves, so a metadata strip that happened later, on a variant, could be walked around.
    def clean_blob(file)
      type = sniffed_type(file)
      cleaned = clean(file.tempfile.path, type)

      # Unattached on purpose: nothing may sweep `Blob.unattached` while a body only holds the URL.
      filename = "#{File.basename(file.original_filename, '.*')}.#{FORMATS.fetch(type)}"
      ActiveStorage::Blob.create_and_upload!(io: cleaned, filename: filename, content_type: type)
    ensure
      cleaned&.close!
    end

    # Auto-oriented and stripped by ImageProcessing; a GIF keeps its frames, so it is not resized.
    def clean(path, type)
      pipeline = ImageProcessing::MiniMagick.source(path).convert(FORMATS.fetch(type)).saver(strip: true, quality: 82)
      pipeline = pipeline.resize_to_limit(MAX_EDGE, MAX_EDGE) unless type == 'image/gif'
      pipeline.call
    end

    # The magic bytes, not the multipart header and not the file name: both are the client's.
    def sniffed_type(file)
      @sniffed_type ||= Marcel::MimeType.for(Pathname(file.tempfile.path))
    end

    # An upload endpoint that any signed-in editor can reach is a place to park files, so it
    # checks what it is and how big before anything is stored.
    def rejection(file)
      return t('.missing') unless file.respond_to?(:tempfile)
      return t('.size', limit: MAX_BYTES / 1.megabyte) if file.size > MAX_BYTES
      return t('.type') unless FORMATS.key?(sniffed_type(file))

      nil
    end
  end
end
