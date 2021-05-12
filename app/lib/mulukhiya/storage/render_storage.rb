module Mulukhiya
  class RenderStorage < Redis
    def set(key, values)
      setex(key, ttl, values.to_s)
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
