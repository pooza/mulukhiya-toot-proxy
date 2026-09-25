module Mulukhiya
  class ListenerDaemon < Ginseng::Daemon
    include Package
    include SNSMethods
    extend DaemonHealthMethods

    def start(args = [])
      save_config
      return Environment.listener_class.start
    end

    def command
      return CommandLine.new([
        File.join(Environment.dir, 'bin/listener_worker.rb'),
      ])
    end

    def self.disable?
      return true unless Environment.dbms_class&.config?
      return true unless Environment.account_class.info_token
      return true if [:follow, :mention].sum {|v| Event.new(v).count}.zero?
      return false
    end

    def self.restart
      return CommandLine.new([File.join(Environment.dir, 'bin/listener_daemon.rb'), 'restart'])
          .exec(timeout: config['/daemon/restart/timeout/seconds'])
    end

    def self.health
      assert_listener_alive!
      check_streaming_endpoint if Environment.mastodon?
      return {status: 'OK'}
    rescue => e
      return {error: e.message, status: 'NG'}
    end

    def self.pid_path
      return File.join(Environment.dir, 'tmp/pids/ListenerDaemon.pid')
    end

    # ⚠ **`exist?` で先に確かめない (#4635 の 5 件目)。**`exist?` と `read` の間に
    # pid ファイルが消えると（デーモン自身の TERM trap が消した直後）、
    # `Errno::ENOENT` が `health` の総括 rescue に落ちて pgrep を試さずに NG になる
    # ＝再起動と `/health` のポーリングが重なったときの偽の NG。読んでみて無ければ
    # pgrep へ倒す（`Ginseng::Daemon#pid` と同じ形。pooza/ginseng-core#561）。
    def self.assert_listener_alive!
      assert_pid_alive!(File.read(pid_path).to_i)
    rescue Errno::ENOENT
      found = system('pgrep', '-f', 'listener_daemon.rb', out: File::NULL, err: File::NULL)
      raise 'listener process not found' unless found
    end

    def self.check_streaming_endpoint
      uri = Ginseng::URI.parse(config['/mastodon/url'])
      uri.path = '/api/v1/streaming/health'
      response = HTTP.new.get(uri)
      raise "streaming returned #{response.code}" unless response.code == 200
    end
  end
end
