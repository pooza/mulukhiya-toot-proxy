module Mulukhiya
  class MediaMetadataStorage < Redis
    def get(path)
      return nil unless entry = super
      return JSON.parse(entry).deep_symbolize_keys
    rescue => e
      logger.error(error: e, key: key)
      return nil
    end

    def push(key)
      if key.is_a?(Ginseng::URI)
        ttl = config['/media/metadata/cache/remote_ttl']
        path = File.join(Environment.dir, 'tmp/media', key.to_s.adler32.to_s)
        File.write(path, http.get(key).body)
      elsif File.exist?(key)
        ttl = config['/media/metadata/cache/ttl']
        path = key
      end
      setex(key.to_s, ttl, MediaFile.new(path).file.values.to_json)
    rescue => e
      logger.error(error: e)
    end

    def http
      unless @http
        @http = HTTP.new
        @http.retry_limit = 1
      end
      return @http
    end

    def create_key(key)
      return super(key.to_s.adler32) if key.is_a?(Ginseng::URI)
      return super(File.read(key).adler32) if File.exist?(key)
      return super
    end

    def prefix
      return 'media_metadata'
    end
  end
end
