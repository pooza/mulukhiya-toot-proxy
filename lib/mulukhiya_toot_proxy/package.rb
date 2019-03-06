module MulukhiyaTootProxy
  module Package
    def environment_class
      return 'MulukhiyaTootProxy::Environment'
    end

    def package_class
      return 'MulukhiyaTootProxy::Package'
    end

    def config_class
      return 'MulukhiyaTootProxy::Config'
    end

    def logger_class
      return 'MulukhiyaTootProxy::Logger'
    end

    def database_class
      return 'MulukhiyaTootProxy::Postgres'
    end

    def query_template_class
      return 'MulukhiyaTootProxy::QueryTemplate'
    end

    def self.name
      return 'mulukhiya-toot-proxy'
    end

    def self.short_name
      return 'mulukhiya'
    end

    def self.version
      return Config.instance['/package/version']
    end

    def self.url
      return Config.instance['/package/url']
    end

    def self.full_name
      return "#{name} #{version}"
    end

    def self.user_agent
      return "#{name}/#{version} (#{url})"
    end
  end
end
