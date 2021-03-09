require 'zlib'

module Mulukhiya
  module AttachmentMethods
    def mediatype
      return type.split('/').first
    end

    def pixel_size
      return nil unless meta
      return nil unless meta[:width]
      return nil unless meta[:height]
      return "#{meta[:width]}x#{meta[:height]}"
    end

    def duration
      return nil unless meta
      return nil unless meta[:duration]
      return meta[:duration].to_f.round(2)
    end

    def meta
      unless @http
        @http = HTTP.new
        @http.retry_limit = 1
      end
      File.write(path, @http.get(uri)) unless File.exist?(path)
      storage = MediaMetadataStorage.new
      storage.push(path) unless storage.get(path)
      return storage.get(path)
    rescue => e
      logger.error(error: e, path: path)
      return nil
    end

    def path
      return File.join(Environment.dir, 'tmp/media/', Zlib.adler32(
        [id, config['/crypt/salt']].to_json,
      ))
    end

    def size_str
      ['', 'Ki', 'Mi', 'Gi', 'Ti', 'Pi', 'Ei', 'Zi', 'Yi'].freeze.each_with_index do |unit, i|
        unitsize = 1024.pow(i)
        return "#{(size.to_f / unitsize).floor.commaize}#{unit}B" if size < unitsize * 1024 * 2
      end
      raise 'Too large'
    end

    def self.included(base)
      base.extend(Methods)
    end

    module Methods
      def query_params
        return {
          limit: config['/feed/media/limit'],
        }
      end
    end
  end
end
