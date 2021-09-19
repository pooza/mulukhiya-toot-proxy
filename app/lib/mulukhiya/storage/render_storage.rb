module Mulukhiya
  class RenderStorage < Redis
    def get(key)
      return nil unless entry = super
      return JSON.parse(entry) rescue entry
    rescue => e
      logger.error(error: e, key: key)
      return nil
    end

    def set(command, value)
      setex(command, ttl, value)
    end

    def setex(command, ttl, value)
      if value.is_a?(Enumerable)
        super(command, ttl, value.to_json)
      else
        super(command, ttl, value.to_s)
      end
    end

    def create_key(key)
      return super(key.to_s.adler32)
    end

    def ttl
      return config['/feed/cache/ttl']
    end

    def prefix
      return 'render'
    end
  end
end
