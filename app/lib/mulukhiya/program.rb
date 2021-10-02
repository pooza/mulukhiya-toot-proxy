module Mulukhiya
  class Program
    include Singleton
    include Package

    def update
      programs = {}
      uris.each do |uri|
        programs.merge!(@http.get(uri).to_h)
      end
      redis['program'] = programs.to_json
    end

    def data
      return JSON.parse(redis['program'] || '{}')
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

    def uris
      return config['/program/urls'].map {|v| Ginseng::URI.parse(v)}.to_set rescue []
    end

    alias to_s to_yaml

    private

    def initialize
      @http = HTTP.new
    end
  end
end
