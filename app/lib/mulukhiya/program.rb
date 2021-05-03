module Mulukhiya
  class Program
    include Singleton
    include Package

    def update
      redis.set('program', @http.get(uri)) if uri
    end

    def data
      return JSON.parse(redis.get('program') || '{}')
    end

    def redis
      @redis ||= Redis.new
      return @redis
    end

    def count
      return data.count
    end

    def to_yaml
      return data.to_yaml
    end

    def uri
      return Ginseng::URI.parse(config['/programs/url']) rescue nil
    end

    alias to_s to_yaml

    private

    def initialize
      @http = HTTP.new
    end
  end
end
