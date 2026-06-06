$LOAD_PATH.unshift(File.join(File.expand_path('../..', __dir__), 'app/lib'))

# FreeBSD rc.d の daemon(8) 起動では FD 1/2 が no-reader pipe になり、書き込みが
# カーネル buffer 枯渇後に discard される (#4362)。puma initializer と同じく壊れた
# stdio を /dev/null に張り替えて EPIPE / ログ消失を防ぐ。
[$stdout, $stderr].each do |io|
  next if io.tty?
  begin
    io.flush
  rescue Errno::EPIPE, IOError
    io.reopen(File::NULL, 'w')
  end
end

require 'mulukhiya'
require 'syslog/logger'
module Mulukhiya
  daemon = SidekiqDaemon.new
  config = YAML.load_file(daemon.config_cache_path).deep_symbolize_keys
  Sidekiq.configure_server do |sidekiq|
    sidekiq.redis = {url: config.dig(:redis, :dsn)}
    sidekiq.concurrency = config[:concurrency]
    # Sidekiq 内部ログ (retry / scheduler / boot 等) を $stdout ではなく syslog へ。
    # Ginseng::Logger と同じ ident (Package.name) / facility (LOG_USER) を使い、puma・
    # WorkerLoggingMiddleware と同じ /var/log/mulukhiya-toot-proxy.log に集約する (#4362)。
    # WorkerLoggingMiddleware が出すジョブライフサイクルログ (#4079) はそのまま維持。
    sidekiq.logger = Syslog::Logger.new(Package.name)
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
