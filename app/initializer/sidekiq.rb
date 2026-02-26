$LOAD_PATH.unshift(File.join(File.expand_path('../..', __dir__), 'app/lib'))

require 'mulukhiya'
module Mulukhiya
  daemon = SidekiqDaemon.new
  config = YAML.load_file(daemon.config_cache_path).deep_symbolize_keys
  Sidekiq.configure_server do |sidekiq|
    sidekiq.redis = {url: config.dig(:redis, :dsn)}
    sidekiq.concurrency = config[:concurrency]
    sidekiq.logger = Sidekiq::Logger.new($stdout)
    sidekiq.logger.level = config.dig(:logger, :level)
    sidekiq.logger.formatter = Sidekiq::Logger::Formatters::JSON.new
    sidekiq.server_middleware do |chain|
      chain.add WorkerLoggingMiddleware
    end
  end
  Sidekiq::Scheduler.enabled = true
  Sidekiq::Scheduler.dynamic = true
  Sidekiq.schedule = config[:schedule]
end
