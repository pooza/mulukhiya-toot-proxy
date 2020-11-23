module Mulukhiya
  class YouTubeService < Ginseng::YouTube::Service
    include Package

    def self.config?
      config = Config.instance
      config['/google/api/key']
      return true
    rescue Ginseng::ConfigError
      return false
    end
  end
end
