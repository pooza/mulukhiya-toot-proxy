require 'sidekiq/api'

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
