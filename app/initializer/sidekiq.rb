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
    # local.yaml で `capsule: null` が混入しても media_catalog キューを listen する
    # capsule が必ず立ち上がるよう defensive default を取る。schema 上 optional だが
    # 未設定 = 専用 capsule 無し = ジョブが Redis に溜まり続ける経路は塞ぐ。
    capsule_config = config.dig(:capsule, :media_catalog) || {}
    sidekiq.capsule(:media_catalog) do |cap|
      cap.queues = ['media_catalog']
      cap.concurrency = capsule_config[:concurrency] || 1
    end
  end
  Sidekiq::Scheduler.enabled = true
  Sidekiq::Scheduler.dynamic = true
  Sidekiq.schedule = config[:schedule]
end
