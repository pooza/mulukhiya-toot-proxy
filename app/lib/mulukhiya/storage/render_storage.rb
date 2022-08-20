module Mulukhiya
  class RenderStorage < Redis
    attr_accessor :ttl

    def initialize(params = {})
      super
      @ttl = 300
    end

    def get(key)
      return nil unless entry = super
      return JSON.parse(entry) rescue entry
    rescue => e
      e.log(key:)
      return nil
    end

    def set(key, value)
      setex(key, ttl, value)
      log(key:)
    end

    def setex(key, ttl, value)
      if value.is_a?(Enumerable)
        super(key, ttl, value.to_json)
      else
        super(key, ttl, value.to_s)
      end
    end

    def create_key(key)
      return super(key.to_s.sha256)
    end

    def prefix
      return 'render'
    end
  end
end
