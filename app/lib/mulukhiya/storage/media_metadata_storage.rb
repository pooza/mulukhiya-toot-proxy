module Mulukhiya
  class MediaMetadataStorage < Redis
    attr_reader :http

    def initialize(params = {})
      super
      @http = HTTP.new
      @http.retry_limit = 1
    end

    def get(uri)
      return supernil unless entry = super
      return JSON.parse(entry).deep_symbolize_keys
    rescue => e
      e.log(key:)
      return nil
    end

    def set(uri, value)
      setex(uri, ttl, value.to_json)
    end

    def push(uri)
      path = File.join(Environment.dir, 'tmp/media', uri.to_s.sha256)
      File.write(path, http.get(uri)) unless File.exist?(path)
      values = MediaFile.new(path).file.values.merge(url: uri.to_s)
      set(uri, values)
      log(url: uri.to_s)
    rescue Ginseng::GatewayError => e
      e.log(url: uri.to_s)
      set(uri, {})
    end

    def ttl
      return config['/media/metadata/cache/ttl']
    end

    def prefix
      return 'media_metadata'
    end
  end
end
