# frozen_string_literal: true

# Post covers. Two sizes, both JPEG, both stripped of metadata.
#
# What this used to be: five versions (lite, thumb, medium, small, large) of which three had
# no reader anywhere in the app, and every one of them `convert`ed to PNG — so a photographic
# cover came out as a 784 KB lossless PNG at 1356×759 to fill a slot 320 px tall. That is the
# single heaviest thing the site put on the wire.
class PhotoUploader < CarrierWave::Uploader::Base
  include CarrierWave::MiniMagick

  storage :file

  # Photographs, not diagrams: JPEG at 80 is indistinguishable here and roughly a tenth of the
  # bytes. `strip` drops EXIF, which also means a cover cannot carry the photographer's GPS
  # coordinates onto a public page.
  COMPRESSION = { quality: 80, strip: true, interlace: 'Plane' }.freeze

  # Wide enough for a 2× screen at the widest the cover is ever drawn (1100 px on /journal),
  # in the 16:9 the CSS already crops to.
  MEDIUM = [1200, 675].freeze
  # The related-entry cards and the admin list thumbnail.
  SMALL = [520, 293].freeze

  # Nothing on this site needs a 20 MB camera original, and an unbounded upload is an
  # unbounded ImageMagick job. nginx's own limit is separate and much larger.
  MAX_BYTES = 8.megabytes

  def store_dir
    "uploads/#{model.class.to_s.underscore}/#{mounted_as}/#{model.id}"
  end

  # The old one was `"#{Time.zone.now} - #{original_filename}"`, which produced paths like
  # "2026-08-24 21:11:31 +0300 - cover.jpg": spaces, colons and a plus sign inside a URL, and
  # a collision for two uploads in the same second. This is sortable, safe in a path, and
  # unique.
  # Memoised, and deliberately not guarded with `if original_filename` — CarrierWave 3 asks
  # for this again after the file is stored, when original_filename is gone, and a nil answer
  # there is what its own warning is about.
  def filename
    @filename ||= "#{Time.zone.now.strftime('%Y%m%d%H%M%S')}-#{SecureRandom.hex(4)}.#{stored_extension}"
  end

  version :medium do
    process crop_to_aspect: MEDIUM
    process resize_to_limit: [*MEDIUM, { combine_options: COMPRESSION }]
    process convert: 'jpg'
  end

  version :small do
    process crop_to_aspect: SMALL
    process resize_to_limit: [*SMALL, { combine_options: COMPRESSION }]
    process convert: 'jpg'
  end

  # Crop to the version's shape, then shrink to fit it — never enlarge.
  #
  # This was one `resize_to_fill`, which does enlarge: a 560×560 source came out as a
  # 1200×675 file, blown up 2.14× and soft, and then the CSS cropped that again to the
  # 2.375:1 banner. A cover that is smaller than the slot should be a smaller sharp file, not
  # a bigger blurry one — the slot is `width: 100%` either way, and a browser upscaling once
  # beats ImageMagick upscaling first and the browser upscaling the result.
  #
  # Two passes rather than one: the crop fixes the shape at full resolution, and
  # resize_to_limit is shrink-only by definition, so a small source simply stops early.
  def crop_to_aspect(width, height)
    manipulate! do |image|
      ratio = width.to_f / height
      crop_width = [image.width, (image.height * ratio).round].min
      crop_height = [(crop_width / ratio).round, image.height].min

      image.combine_options do |options|
        options.gravity 'Center'
        options.crop "#{crop_width}x#{crop_height}+0+0"
        # -crop leaves the original canvas geometry in the header; without this the JPEG is
        # the right pixels on a page the old size, and every later step reads the old size.
        options.repage.+
      end

      image
    end
  end

  def extension_allowlist
    %w[jpg jpeg gif png webp]
  end

  # The extension is what the uploader claims; this is what the bytes actually are. Without
  # it, "payload.php" renamed to "payload.jpg" reached ImageMagick on the strength of its name.
  def content_type_allowlist
    [%r{\Aimage/}]
  end

  def size_range
    1..MAX_BYTES
  end

  private

  def stored_extension
    source = original_filename.presence || file&.extension
    extension = File.extname(source.to_s).delete('.').presence || source.to_s
    extension.downcase.presence || 'jpg'
  end
end
