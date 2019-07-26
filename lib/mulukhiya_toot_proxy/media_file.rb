require 'digest/sha1'

module MulukhiyaTootProxy
  class MediaFile < File
    def initialize(path, mode = 'r', perm = 0o666)
      @logger = Logger.new
      super(path, mode, perm)
    end

    def valid?
      return File.readable?(path) && type.present?
    end

    def mime_type
      return `file --mime-type #{path.shellescape}`.chomp.split(' ').last
    end

    def type
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
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

    def detail_info
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end
  end
end
