module Mulukhiya
  class ImageFile < MediaFile
    def values
      return {
        type:,
        mediatype:,
        subtype:,
        width:,
        height:,
        size:,
        length: size,
      }
    end

    alias to_h values

    def width
      return size_info[:width]
    end

    def height
      return size_info[:height]
    end

    def type
      return @type if @type
      if Environment.mastodon?
        command = CommandLine.new(['file', '-b', '--mime', path])
        command.exec
        @type ||= command.stdout.split(';').first if command.status.zero?
      end
      @type ||= super
      @type ||= detail_info.match(/\s+Mime\stype:\s*(.*)$/i)[1]
      return @type
    rescue => e
      e.log(file: path)
      return @type = super
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
    rescue => e
      e.log(file: path)
      return nil
    end

    def alpha?
      return false unless image?
      command = CommandLine.new(['identify', '-format', '%[channels]', path])
      command.exec
      return /rgba/i.match?(command.stdout)
    end

    def animated?
      return false unless image?
      command = CommandLine.new(['identify', path])
      command.exec
      return true if 1 < command.stdout.each_line.count
      command = CommandLine.new(['ffprobe', path])
      command.exec
      return true if command.stderr.match?(/Stream .* Video: apng/)
      return false
    end

    def resize(pixel)
      dest = create_dest_path(f: __method__, p: pixel, type: subtype)
      command = CommandLine.new(['convert', '-resize', "#{pixel}x#{pixel}", path, dest])
      command.exec unless File.exist?(dest)
      return ImageFile.new(dest)
    end

    def trim!(fuzz = '20%')
      command = CommandLine.new(['mogrify', '-fuzz', fuzz, '-trim', '+repage', path])
      command.exec
      @size_info = nil
      @detail_info = nil
    end

    def convert_type(type)
      return convert_animation_type(type) if animated?
      dest = create_dest_path(f: __method__, type:)
      command = CommandLine.new(['convert', path, dest])
      command.exec unless File.exist?(dest)
      if command.status&.positive?
        message = command.stderr.split(/[\n`]/).first
        raise "#{self.type} allowed by the security policy?" if message.include?('security policy')
        raise message
      end
      unless File.exist?(dest)
        finder = Ginseng::FileFinder.new
        finder.dir = File.dirname(dest)
        finder.patterns.push("#{File.basename(dest, '.*')}-*#{File.extname(dest)}")
        dest = finder.exec.max
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
      e.log(file: path)
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
      e.log(file: path)
      return nil
    end
  end
end
