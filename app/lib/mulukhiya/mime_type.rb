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
      @types ||= Rack::Mime::MIME_TYPES
      @extnames ||= @types.invert
    end
  end
end
