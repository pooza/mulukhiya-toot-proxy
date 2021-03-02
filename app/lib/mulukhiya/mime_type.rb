require 'rack/mime'

module Mulukhiya
  class MIMEType
    include Singleton
    attr_reader :types, :extnames

    def extname(type)
      return @extnames[type]
    end

    def type(ext)
      return @types[ext]
    end

    def self.extname(type)
      return instance.extnames[type]
    end

    def self.type(ext)
      return instance.types[ext]
    end

    private

    def initialize
      @types = Rack::Mime::MIME_TYPES
      @types['.mp4'] = 'video/mp4'
      @types['.mp3'] = 'audio/mpeg'
      @types['.webp'] = 'image/webp'
      @extnames = @types.invert
      @extnames['video/mp4'] = '.mp4'
      @extnames['audio/mpeg'] = '.mp3'
    end
  end
end
