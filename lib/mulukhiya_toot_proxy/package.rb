module MulukhiyaTootProxy
  module Package
    def module_name
      return 'MulukhiyaTootProxy'
    end

    def environment_class
      return "#{module_name}::Environment"
    end

    def package_class
      return "#{module_name}::Package"
    end

    def config_class
      return "#{module_name}::Config"
    end

    def logger_class
      return "#{module_name}::Logger"
    end

    def database_class
      return "#{module_name}::Postgres"
    end

    def query_template_class
      return "#{module_name}::QueryTemplate"
    end

    def http_class
      return "#{module_name}::HTTP"
    end

    def you_tube_service_class
      return "#{module_name}::YouTubeService"
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
