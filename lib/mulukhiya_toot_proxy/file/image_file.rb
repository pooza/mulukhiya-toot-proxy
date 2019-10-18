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

    def duration
      return nil
    end

    def alpha?
      return image? && (detail_info =~ /  alpha:\s+(s?rgb|none)/i).present?
    end

    def resize(pixel)
      dest = create_dest_path(f: __method__, p: pixel, type: subtype)
      command = CommandLine.new(['convert', '-resize', "#{pixel}x#{pixel}", path, dest])
      command.exec unless File.exist?(dest)
      return ImageFile.new(dest)
    end

    def convert_type(type)
      dest = create_dest_path(f: __method__, type: type)
      command = CommandLine.new(['convert', path, dest])
      command.exec unless File.exist?(dest)
      unless File.exist?(dest)
        mask = File.join(
          File.dirname(dest),
          "#{File.basename(dest, '.*')}-*#{File.extname(dest)}",
        )
        dest = Dir.glob(mask).max
      end
      return ImageFile.new(dest)
    end

    def detail_info
      unless @detail_info
        command = CommandLine.new
        begin
          command.args = ['identify', '-verbose', path]
          command.exec
          @detail_info = command.stdout
        rescue
          command.args = ['identify', path]
          command.exec
          @detail_info = command.stdout
        end
      end
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
