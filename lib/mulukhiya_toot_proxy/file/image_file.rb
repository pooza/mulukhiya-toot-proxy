require 'fastimage'
require 'digest/sha1'

module MulukhiyaTootProxy
  class ImageFile < File
    def initialize(path, mode = 'r', perm = 0666)
      @logger = Logger.new
      super(path, mode, perm)
    end

    def image?
      return File.readable?(path) && type.present?
    end

    def mime_type
      return nil unless image?
      return "image/#{type}"
    end

    def type
      return FastImage.type(path)
    rescue
      return nil
    end

    def width
      return size_info[:width]
    end

    def height
      return size_info[:height]
    end

    def aspect
      return width / height
    end

    def long_side
      return [width, height].max
    end

    def alpha?
      return image? && (detail_info =~ /  alpha:/i).present?
    end

    def resize(pixel)
      dest = File.join(Environment.dir, 'tmp/media', "#{digest(f: __method__)}.#{type}")
      system('convert', '-resize', "#{pixel}x#{pixel}", path, dest, {exception: true})
      return ImageFile.new(dest)
    end

    def convert_type(type)
      dest = File.join(Environment.dir, 'tmp/media', "#{digest(f: __method__)}.#{type}")
      system('convert', path, dest, {exception: true})
      return ImageFile.new(dest)
    end

    def digest(params)
      return Digest::SHA1.hexdigest(
        params.merge(
          content: Digest::SHA1.hexdigest(File.read(path)),
        ).to_json,
      )
    end

    def detail_info
      @detail_info ||= `identify -verbose #{path.shellescape}`
      return @detail_info
    rescue => e
      @logger.error(e)
      return nil
    end

    def size_info
      return nil unless image?
      unless @size_info
        size = FastImage.size(path)
        @size_info = {width: size[0], height: size[1]}
      end
      return @size_info
    rescue => e
      @logger.error(e)
      return nil
    end
  end
end
