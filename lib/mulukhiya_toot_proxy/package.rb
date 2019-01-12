module MulukhiyaTootProxy
  class Package < Ginseng::Package
    def self.name
      return 'mulukhiya-toot-proxy'
    end

    def self.short_name
      return 'mulukhiya'
    end

    def self.config_class
      return 'MulukhiyaTootProxy::Config'
    end
  end
end
