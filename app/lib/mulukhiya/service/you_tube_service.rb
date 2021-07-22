module Mulukhiya
  class YouTubeService < Ginseng::YouTube::Service
    include Package

    def api_key
      return YouTubeService.api_key
    end

    def self.api_key
      return config['/google/api/key'].decrypt
    rescue Ginseng::ConfigError
      return nil
    rescue
      return config['/google/api/key']
    end

    def self.config?
      return false unless api_key
      return true
    end
  end
end
