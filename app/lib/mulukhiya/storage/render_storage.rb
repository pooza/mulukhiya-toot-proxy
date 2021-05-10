module Mulukhiya
  class RenderStorage < Redis
    def [](key)
      return get(key)
    end

    def get(command)
      return super(create_key(command))
    end

    def setex(command, ttl, value)
      return super(create_key(command), ttl, value.to_s)
    end

    def create_key(key)
      return super(key.to_s.adler32)
    end

    def prefix
      return 'render'
    end
  end
end
