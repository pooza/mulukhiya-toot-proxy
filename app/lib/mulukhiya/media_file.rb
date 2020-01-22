require 'digest/sha1'
require 'mimemagic'

module Mulukhiya
  class MediaFile < File
    def initialize(path, mode = 'r', perm = 0o600)
      @logger = Logger.new
      super(path, mode, perm)
    end

    def valid?
      return mediatype == default_mediatype
    end

    def mediatype
      return mimemagic&.mediatype
    end

    def default_mediatype
      return self.class.to_s.split('::').last.underscore.split('_').first
    end

    def subtype
      return mimemagic&.subtype
    end

    def type
      return mimemagic&.to_s
    end

    def width
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end

    def height
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end

    def duration
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end

    def aspect
      return width.to_f / height
    rescue
      return nil
    end

    def long_side
      return [width, height].max
    rescue
      return nil
    end

    def convert_type(type)
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end

    def create_dest_path(params = {})
      params[:type] ||= default_mediatype
      params[:content] = Digest::SHA1.hexdigest(File.read(path))
      return File.join(
        Environment.dir,
        'tmp/media',
        "#{Digest::SHA1.hexdigest(params.to_json)}.#{params[:type]}",
      )
    end

    def mimemagic
      @mimemagic ||= MimeMagic.by_magic(self)
      return @mimemagic
    end

    def detail_info
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end
  end
end
