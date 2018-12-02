require 'sidekiq'
require 'singleton'

module MulukhiyaTootProxy
  class Sidekiq
    include Singleton

    def initialize
      @config = Config.instance

      ::Sidekiq.configure_server do |config|
        config.redis = {url: @config['/sidekiq/redis/dsn']}
      end

      ::Sidekiq.configure_client do |config|
        config.redis = {url: @config['/sidekiq/redis/dsn']}
      end
    end

    def create_worker(name)
      require File.join(ROOT_DIR, 'app/workers', "#{name}_worker")
      return "MulukhiyaTootProxy::#{name.camelize}Worker".constantize
    end
  end
end
