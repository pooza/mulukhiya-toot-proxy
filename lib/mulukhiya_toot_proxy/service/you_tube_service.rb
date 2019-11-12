module MulukhiyaTootProxy
  class YouTubeService < Ginseng::YouTubeService
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
