require 'mulukhiya/config'

module MulukhiyaTootProxy
  module Package
    def self.name
      return 'mulukhiya-toot-proxy'
    end

    def self.version
      return Config.instance['application']['package']['version']
    end

    def self.url
      return Config.instance['application']['package']['url']
    end

    def self.full_name
      return "#{name} #{version}"
    end
  end
end
