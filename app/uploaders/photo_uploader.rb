# frozen_string_literal: true

# Post covers. The stored original is stripped and upright, and the two sizes are JPEGs.
class PhotoUploader < CarrierWave::Uploader::Base
  include CarrierWave::MiniMagick

  storage :file

  # `strip` drops EXIF, so a cover cannot carry the photographer's GPS onto a public page.
  COMPRESSION = { quality: 80, strip: true, interlace: 'Plane' }.freeze

  # Wide enough for a 2× screen at the widest the cover is ever drawn (1100 px on /journal),
  # in the 16:9 the CSS already crops to.
  MEDIUM = [1200, 675].freeze
  # The related-entry cards and the admin list thumbnail.
  SMALL = [520, 293].freeze

  # An unbounded upload is an unbounded ImageMagick job. nginx's own limit is separate and
  # much larger.
  MAX_BYTES = 8.megabytes

  CACHE_TTL = 1.day

  before :cache, :purge_stale_cache

  process :normalize

  version :medium do
    force_extension 'jpg'
    process cover: MEDIUM
  end

  version :small do
    force_extension 'jpg'
    process cover: SMALL
  end

  def store_dir
    "uploads/#{model.class.to_s.underscore}/#{mounted_as}/#{model.id}"
  end

  # CarrierWave sets @filename to the client's name when it caches, so the unique name has to
  # live elsewhere. It is asked for again after the file is stored, when original_filename is
  # gone, so it must not be guarded on it.
  def filename
    "#{secure_token}.#{stored_extension}"
  end

  def cache!(*)
    @secure_token = nil
    super
  end

  # Runs on the stored original, before any version is cut from it: one frame, upright, no
  # metadata. Versions read its pixel size, so the rotation has to be applied by then.
  def normalize
    minimagick! do |builder|
      stripped = builder.loader(page: 0).strip
      %w[jpg jpeg].include?(stored_extension) ? stripped.background('white').alpha('remove').alpha('off') : stripped
    end
  end

  # Crop to the version's shape, then shrink to fit it, never enlarge: a cover smaller than
  # the slot should be a smaller sharp file, not a blurry one. One ImageMagick pass, so the
  # JPEG is encoded once and COMPRESSION applies to it whatever the source format was.
  def cover(width, height)
    source_width, source_height = ::MiniMagick::Image.new(current_path).dimensions
    ratio = width.to_f / height
    crop_width = [source_width, (source_height * ratio).round].min
    crop_height = [(crop_width / ratio).round, source_height].min

    minimagick! do |builder|
      builder.convert('jpg').saver(**COMPRESSION)
             .background('white').alpha('remove').alpha('off')
             .gravity('Center').crop("#{crop_width}x#{crop_height}+0+0").append('+repage')
             .resize_to_limit(width, height)
    end
  end

  def extension_allowlist
    %w[jpg jpeg gif png webp]
  end

  # By the bytes, not the name, and not `image/*`: SVG, TIFF and PSD are images ImageMagick
  # would render with coders this site has no use for.
  def content_type_allowlist
    %w[image/jpeg image/png image/gif image/webp]
  end

  def size_range
    1..MAX_BYTES
  end

  private

  def secure_token
    @secure_token ||= "#{Time.zone.now.strftime('%Y%m%d%H%M%S')}-#{SecureRandom.hex(4)}"
  end

  def stored_extension
    source = original_filename.presence || file&.extension
    extension = File.extname(source.to_s).delete('.').presence || source.to_s
    extension.downcase.presence || 'jpg'
  end

  # A save that fails validation leaves its cache directory behind; nothing else ever empties it.
  def purge_stale_cache(_new_file)
    self.class.clean_cached_files!(CACHE_TTL.to_i) unless parent_version
  end
end
