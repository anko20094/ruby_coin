# frozen_string_literal: true

# Images built on the spot, because the uploaders are judged on bytes: whether the camera's
# make survived, which way the pixels face, whether the corner is black. MiniMagick draws the
# picture and #jpeg_with_exif splices in the APP1 segment a phone would have written.
module ImageFixtures
  CAMERA_MAKE = 'SECRETCAMERA'
  EXIF_MARKER = "Exif\0\0".b.freeze

  ASCII = 2
  SHORT = 3
  LONG = 4
  RATIONAL = 5

  module_function

  def plain_image(path, width:, height:)
    FileUtils.mkdir_p(File.dirname(path))
    MiniMagick.convert { |convert| convert.size("#{width}x#{height}") << 'xc:gray' << path.to_s }
    path
  end

  def jpeg_with_exif(path, width:, height:, orientation: 1)
    bytes = File.binread(plain_image(path, width: width, height: height))
    payload = exif_payload(orientation)
    segment = "\xFF\xE1".b + [payload.bytesize + 2].pack('n') + payload
    File.binwrite(path, bytes[0, 2] + segment + bytes[2..])
    path
  end

  def png_with_alpha(path, width:, height:)
    FileUtils.mkdir_p(File.dirname(path))
    MiniMagick.convert do |convert|
      convert.size("#{width}x#{height}")
      convert << 'xc:none'
      convert.fill('red')
      convert.draw("circle #{width / 2},#{height / 2} #{width / 2},#{height / 4}")
      convert << path.to_s
    end
    path
  end

  def animated_gif(path, frames: 3)
    FileUtils.mkdir_p(File.dirname(path))
    MiniMagick.convert do |convert|
      convert.delay(10)
      convert.size('200x150')
      frames.times { |i| convert << "xc:gray#{(i + 1) * 20}" }
      convert.loop(0)
      convert << path.to_s
    end
    path
  end

  def exif_payload(orientation)
    make = "#{CAMERA_MAKE}\0".b
    make = make.ljust(make.bytesize + (make.bytesize % 2), "\0")
    make_at = 8 + 2 + (3 * 12) + 4
    gps_at = make_at + make.bytesize
    latitude_at = gps_at + 2 + (4 * 12) + 4

    tiff = 'II'.b + [42, 8].pack('vV') + ifd0(orientation, make.bytesize, make_at, gps_at) + make +
           gps_ifd(latitude_at, latitude_at + 24) + [50, 1, 27, 1, 0, 1].pack('V*') + [30, 1, 31, 1, 0, 1].pack('V*')

    EXIF_MARKER + tiff
  end

  def ifd0(orientation, make_size, make_at, gps_at)
    [3].pack('v') +
      entry(0x010F, ASCII, make_size, [make_at].pack('V')) +
      entry(0x0112, SHORT, 1, [orientation, 0].pack('vv')) +
      entry(0x8825, LONG, 1, [gps_at].pack('V')) + [0].pack('V')
  end

  def gps_ifd(latitude_at, longitude_at)
    [4].pack('v') +
      entry(1, ASCII, 2, "N\0\0\0".b) + entry(2, RATIONAL, 3, [latitude_at].pack('V')) +
      entry(3, ASCII, 2, "E\0\0\0".b) + entry(4, RATIONAL, 3, [longitude_at].pack('V')) + [0].pack('V')
  end

  def entry(tag, type, count, value) = [tag, type, count].pack('vvV') + value
end
