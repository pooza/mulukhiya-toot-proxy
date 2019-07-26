require 'digest/sha1'
require 'mimemagic'

module MulukhiyaTootProxy
  class MediaFile < File
    def initialize(path, mode = 'r', perm = 0o666)
      @logger = Logger.new
      super(path, mode, perm)
    end

    def valid?
      return mediatype == self.class.to_s.split('::').last.underscore.split('_').first
    end

    def mediatype
      return mimemagic.mediatype
    end

    def subtype
      return mimemagic.subtype
    end

    def type
      return mimemagic.to_s
    end

    def convert_type(type)
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end

    def digest(params)
      return Digest::SHA1.hexdigest(
        params.merge(
          content: Digest::SHA1.hexdigest(File.read(path)),
        ).to_json,
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
