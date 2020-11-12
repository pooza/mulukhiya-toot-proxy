module Mulukhiya
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

    def type
      @type ||= super
      @type ||= detail_info.match(/\s+Mime\stype:\s*(.*)$/i)[1]
      return @type
    rescue NoMethodError
      return nil
    end

    def mediatype
      @mediatype ||= super
      @mediatype ||= detail_info.match(%r{\s+Mime\stype:\s*(.*)/}i)[1]
      return @mediatype
    rescue NoMethodError
      return nil
    end

    def subtype
      @subtype ||= super
      @subtype ||= detail_info.match(%r{\s+Mime\stype:\s*(.*)/(.*)}i)[2]
      return @subtype
    rescue NoMethodError
      return nil
    end

    def alpha?
      return false unless image?
      command = CommandLine.new(['identify', '-format', '%[opaque]', path])
      command.exec
      return /False/i.match?(command.stdout)
    end

    def animated?
      return false unless image?
      command = CommandLine.new(['identify', path])
      command.exec
      return true if 1 < command.stdout.each_line.count
      command = CommandLine.new(['ffprobe', path])
      command.exec
      return true if command.stderr.match?(/Stream .* Video: .*fps/)
      return false
    end

    def resize(pixel)
      dest = create_dest_path(f: __method__, p: pixel, type: subtype)
      command = CommandLine.new(['convert', '-resize', "#{pixel}x#{pixel}", path, dest])
      command.exec unless File.exist?(dest)
      return ImageFile.new(dest)
    end

    def trim!(fuzz = '10%')
      command = CommandLine.new(['mogrify', '-fuzz', fuzz, '-trim', '+repage', path])
      command.exec
      @size_info = nil
      @detail_info = nil
    end

    def convert_type(type)
      return convert_animation_type(type) if animated?
      dest = create_dest_path(f: __method__, type: type)
      command = CommandLine.new(['convert', path, dest])
      command.exec unless File.exist?(dest)
      raise command.stderr.split(/[\n`]/).first if command.status&.positive?
      unless File.exist?(dest)
        mask = File.join(
          File.dirname(dest),
          "#{File.basename(dest, '.*')}-*#{File.extname(dest)}",
        )
        dest = Dir.glob(mask).max
      end
      return ImageFile.new(dest)
    end

    def convert_animation_type(type = 'image/gif')
      return unless animated?
      dest = create_dest_path(f: __method__, extname: MIMEType.extname(type))
      case self.type
      when 'image/png'
        command = CommandLine.new(['ffmpeg', '-i', path, dest])
        command.exec
      when 'image/webp'
        command = CommandLine.new(['convert', path, dest])
        command.exec
      end
      file = ImageFile.new(dest)
      return file if file.type == type
      return nil
    rescue => e
      @logger.error(e)
      return nil
    end

    def detail_info
      unless @detail_info
        command = CommandLine.new(['identify', '-verbose', path])
        command.exec
        @detail_info = command.stdout
      end
      return @detail_info
    end

    def size_info
      unless @size_info
        size = FastImage.size(path)
        if size.present?
          @size_info = {width: size[0], height: size[1]}
        else
          command = CommandLine.new(['identify', '-format', '%[width]x%[height]', path])
          command.exec
          size = command.stdout.split('x')
          @size_info = {width: size[0].to_i, height: size[1].to_i}
        end
      end
      return @size_info
    rescue => e
      @logger.error(e)
      return nil
    end
  end
end
