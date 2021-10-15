module Mulukhiya
  class MediaMetadataStorage < Redis
    attr_reader :http

    def initialize(params = {})
      super
      @http = HTTP.new
      @http.retry_limit = 1
    end

    def get(path)
      return nil unless entry = super
      return JSON.parse(entry).deep_symbolize_keys
    rescue => e
      logger.error(error: e, key: key)
      return nil
    end

    def push(key)
      if key.is_a?(Ginseng::URI)
        path = File.join(Environment.dir, 'tmp/media', key.to_s.adler32)
        File.write(path, http.get(key)) unless File.exist?(path)
        values = MediaFile.new(path).file.values.merge(url: key.to_s)
      else
        key = key.path if key.is_a?(File)
        values = MediaFile.new(key).file.values
      end
      setex(key, ttl, values.to_json)
    end

    def create_key(key)
      if key.is_a?(Ginseng::URI)
        key = File.join(Environment.dir, 'tmp/media', key.to_s.adler32)
        File.write(path, http.get(key)) unless File.exist?(key)
      end
      return super(File.read(key).adler32)
    end

    def ttl
      return config['/media/metadata/cache/ttl']
    end

    def prefix
      return 'media_metadata'
    end
  end
end
