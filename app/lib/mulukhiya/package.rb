module Mulukhiya
  module Package
    def environment_class
      return Environment
    end

    def package_class
      return Package
    end

    def config_class
      return Config
    end

    def config
      return Config.instance
    end

    def logger_class
      return Logger
    end

    def logger
      @logger ||= Logger.new
      return @logger
    end

    def template_class
      return Template
    end

    def database_class
      return Postgres
    end

    def query_template_class
      return QueryTemplate
    end

    def http_class
      return HTTP
    end

    def you_tube_service_class
      return YouTubeService
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

    def self.description
      return Config.instance['/package/description']
    end

    def self.authors
      return Config.instance['/package/authors']
    end

    def self.full_name
      return "#{name} #{version}"
    end

    def self.user_agent
      return "#{name}/#{version} (#{url})"
    end

    def self.included(base)
      base.extend(Methods)
    end

    module Methods
      def logger
        return Logger.new
      end

      def config
        return Config.instance
      end
    end
  end
end
