require 'rack/mime'

module Mulukhiya
  class MIMEType
    include Singleton

    DEFAULT = 'application/octet-stream'.freeze
    attr_reader :types, :extnames

    def extname(type)
      return @extnames[type]
    end

    def type(ext)
      ext = File.extname(ext) if File.extname(ext).present?
      return @types[ext] || DEFAULT
    rescue
      return DEFAULT
    end

    def self.extname(type)
      return instance.extname(type)
    end

    def self.type(ext)
      return instance.type(ext)
    end

    private

    def initialize
      @types = Rack::Mime::MIME_TYPES
      @types['.mp4'] = 'video/mp4'
      @types['.mp3'] = 'audio/mpeg'
      @types['.webp'] = 'image/webp'
      @types['.md'] = 'text/markdown'
      @types['.mkv'] = 'video/x-matroska'
      @extnames = @types.invert
      @extnames['video/mp4'] = '.mp4'
      @extnames['audio/mpeg'] = '.mp3'
    end
  end
end
