module Mulukhiya
  class ListenerDaemon < Ginseng::Daemon
    include Package
    include SNSMethods
    include DaemonIdentityMethods
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

    # ⚠ listener は `exec` しないので、proctitle は "bin/listener_daemon.rb start" のまま
    # （FreeBSD の `ps` では "ruby: bin/listener_daemon.rb start (ruby)"）。
    def process_pattern
      return launcher_pattern('listener_daemon.rb')
    end

    # ⚠ ストリーミングを切った系統（`capabilities/streaming: false`）と、listener のクラスが無い系統は
    # 起動対象に入れない（PR #4844 の Codex P1）。入れると `nil.start` で落ち、`/health` も 503 になる。
    # Mastodon / Misskey は既定で true なので挙動は変わらない。
    def self.disable?
      return true unless Environment.controller_class&.streaming?
      return true unless Environment.listener_class
      return true unless Environment.dbms_class&.config?
      return true unless Environment.account_class.info_token
      return true if [:follow, :mention].sum {|v| Event.new(v).count}.zero?
      return false
    end

    def self.restart
      return CommandLine.new([File.join(Environment.dir, 'bin/listener_daemon.rb'), 'restart'])
          .exec(timeout: config['/daemon/restart/timeout/seconds'])
    end

    # ⚠⚠ **自サーバーの名前が引けないだけなら NG にしない (#4821)。**`status` が NG だと
    # health 全体が 503 になり、monit が 3 デーモンを再起動する。名前解決の失敗は
    # **再起動しても直らない**ので、戻るまで再起動を繰り返すだけになる（2026-10-12 に
    # キュアスタ！で 80 分の間に 4 回）。`error` と `unresolved` は残すので、監視側は
    # そちらを見る（`pgbouncer.error` と同じ扱い）。
    # ⚠ 外すのは名前解決の失敗だけ。繋がって 5xx・接続拒否・タイムアウトは NG のまま。
    # ⚠ listener の生死（`assert_listener_alive!`）は先に見ているので、ここへ来るのは
    # プロセスが居るときだけ。
    def self.health
      assert_listener_alive!
      check_streaming_endpoint if Environment.mastodon?
      return {status: 'OK'}
    rescue => e
      return {error: e.message, unresolved: true, status: 'OK'} if name_resolution_error?(e)
      return {error: e.message, status: 'NG'}
    end

    # ⚠ gem は `Socket::ResolutionError` を `GatewayError` に包むので、`cause` を辿る。
    # 文言の照合は、包み方が変わって `cause` が切れたときの備え。
    def self.name_resolution_error?(error)
      current = error
      while current
        return true if current.is_a?(Socket::ResolutionError)
        return true if current.is_a?(SocketError) && current.message.include?('getaddrinfo')
        current = current.cause
      end
      return error.message.include?('getaddrinfo')
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
