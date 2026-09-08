require 'sidekiq/api'
# ⚠ capsule は sidekiq の CLI が読む。configure_server を CLI の外から
# 検査できるようにここで明示的に読む (#4687)。
require 'sidekiq/capsule'
require 'syslog/logger'

module Mulukhiya
  class SidekiqDaemon < Ginseng::Daemon
    include Package
    extend DaemonHealthMethods

    # 停止要求から hard shutdown（積み残しをキューへ戻す経路）までの締切 (秒)。
    #
    # ⚠⚠ **rc.d の `mulukhiya_sidekiq_kill_wait` と対になる値 (#4675 の Codex P1)。**
    # rc.d の SIGKILL がこの締切より先に撃たれると、Sidekiq は hard shutdown へ
    # 到達できない。⚠ **本リポジトリのワーカーは 15 本中 14 本が `retry: false`**
    # なので、その仕事は再送もされずに**消える**。
    #
    # ⚠ 値そのものは Sidekiq 8.1.7 の既定と同じだが、**既定に任せない**。
    # 上流が既定を動かすと rc.d 側と黙って食い違うため、ここで明示して
    # `test/unit/daemon/sidekiq_daemon.rb` から rc.d の待ち時間と突き合わせる。
    SHUTDOWN_TIMEOUT = 25

    def command
      return CommandLine.new([
        'sidekiq',
        '--require', initializer_path
      ])
    end

    def self.username
      return config['/sidekiq/auth/user'] rescue nil
    end

    def self.password
      return config['/sidekiq/auth/password'].decrypt
    rescue Ginseng::ConfigError
      return nil
    rescue
      return config['/sidekiq/auth/password']
    end

    def self.basic_auth?
      return username.present? && password.present?
    end

    def self.auth?(username, password)
      return true unless basic_auth?
      return false unless username == self.username
      return false unless password == self.password
      return true
    end

    def self.disable?
      return false
    end

    def self.restart
      CommandLine.new([File.join(Environment.dir, 'bin/sidekiq_daemon.rb'), 'restart'])
        .exec(timeout: config['/daemon/restart/timeout/seconds'])
    end

    # `Sidekiq.configure_server` に渡す設定をここへ置く (#4687)。
    #
    # ⚠⚠ **initializer のブロックへ直接書かないこと。**`Sidekiq.configure_server` は
    # `Sidekiq.server?` が false の環境では yield しない ＝ **sidekiq の CLI でしか
    # 実行されない**ので、あちらへ書いた行は `rake test` でも fedi-test-harness でも
    # puma からも走らない。🔴 **#4687（`Sidekiq::Config#timeout=` は存在しない）は
    # それで CI 緑・harness 両系緑のまま、本番の起動で初めて発火した。**
    # ここへ置けば `test/unit/daemon/sidekiq_daemon.rb` が実物の `Sidekiq::Config` を
    # 渡して検査できる。
    def self.configure_server(sidekiq, config)
      sidekiq.redis = {url: config.dig(:redis, :dsn)}
      sidekiq.concurrency = config[:concurrency]
      # ⚠⚠ **停止の締切を上流の既定に任せない (#4675 の Codex P1)。**rc.d の
      # `mulukhiya_sidekiq_kill_wait` はこの値より長くなければならず、暗黙の既定の
      # ままだと上流のバージョン更新で黙って食い違う。詳細は SHUTDOWN_TIMEOUT。
      # ⚠ `timeout` は `Sidekiq::Config` の素のキーで、**setter は無い** (#4687)。
      sidekiq[:timeout] = SHUTDOWN_TIMEOUT
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
      return sidekiq
    end

    def self.health
      stats = Sidekiq::Stats.new
      pids = Sidekiq::ProcessSet.new.map {|p| p['pid']}
      values = {
        queues: stats.queues.slice('default', 'media_catalog').transform_keys(&:to_sym),
        retry: stats.retry_size,
        status: pids.present? ? 'OK' : 'NG',
      }
      pids.each {|pid| assert_pid_alive!(pid)}
      return values
    rescue => e
      return {error: e.message, status: 'NG'}
    end

    def initializer_path
      return File.join(Environment.dir, 'app/initializer/sidekiq.rb')
    end
  end
end
