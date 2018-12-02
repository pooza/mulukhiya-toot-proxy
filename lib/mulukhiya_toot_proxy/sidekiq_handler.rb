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
      @body = body
      @headers = headers
      return unless executable?
      worker_name.constantize.perform_async(param)
      increment!
    end

    def worker_name
      return self.class.to_s.sub(/Handler$/, 'Worker')
    end

    def executable?
      raise ImprementError, "#{__method__}が未実装です。"
    end

    def param
      raise ImprementError, "#{__method__}が未実装です。"
    end
  end
end
