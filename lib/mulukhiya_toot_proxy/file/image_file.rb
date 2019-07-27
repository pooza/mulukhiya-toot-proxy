require 'fastimage'

module MulukhiyaTootProxy
  class ImageFile < MediaFile
    alias image? valid?

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
      dest = File.join(Environment.dir, 'tmp/media', "#{digest(f: __method__)}.#{subtype}")
      unless File.exist?(dest)
        system('convert', '-resize', "#{pixel}x#{pixel}", path, dest, {exception: true})
      end
      return ImageFile.new(dest)
    end

    def convert_type(type)
      dest = File.join(Environment.dir, 'tmp/media', "#{digest(f: __method__)}.#{type}")
      system('convert', path, dest, {exception: true}) unless File.exist?(dest)
      return ImageFile.new(dest)
    end

    def detail_info
      @detail_info ||= `identify -verbose #{path.shellescape}`
      return @detail_info
    end

    def size_info
      return nil unless image?
      unless @size_info
        size = FastImage.size(path)
        @size_info = {width: size[0], height: size[1]}
      end
      return @size_info
    end
  end
end
