require 'sidekiq'

module MulukhiyaTootProxy
  class SidekiqHandler < Handler
    def initialize
      super
      Sidekiq.configure_client do |config|
        config.redis = {url: @config['/sidekiq/redis/dsn']}
      end
    end

    def exec(body, headers = {})
      return unless executable?(body, headers)
      worker_name.constantize.perform_async(create_params(body, headers))
      increment!
    end

    def worker_name
      return self.class.to_s.sub(/Handler$/, 'Worker')
    end

    def executable?(body, headers)
      raise ImplementError, "'#{__method__}' not implemented"
    end

    def create_params(body, headers)
      raise ImplementError, "'#{__method__}' not implemented"
    end
  end
end
