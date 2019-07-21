require 'fastimage'
require 'digest/sha1'

module MulukhiyaTootProxy
  class ImageFile < File
    def image?
      return type.present?
    end

    def mime_type
      return "image/#{type}" if image?
      return nil
    end

    def type
      return FastImage.type(path)
    rescue
      return nil
    end

    def width
      return info[:width]
    end

    def height
      return info[:height]
    end

    def long_side
      return [width, height].max
    end

    def resize(pixel)
      dest = File.join(
        Environment.dir,
        'tmp/media',
        "#{Digest::SHA1.hexdigest(File.read(path))}.#{type}",
      )
      system('convert', '-resize', "#{pixel}x#{pixel}", path, dest)
      return ImageFile.new(dest)
    end

    def info
      return nil unless image?
      unless @info
        size = FastImage.size(path)
        @info = {
          width: size[0],
          height: size[1],
        }
      end
      return @info
    end
  end
end
