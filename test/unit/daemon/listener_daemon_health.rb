module Mulukhiya
  # ListenerDaemon.health が pid ファイルをどう読むか (#4635 の 5・6 件目)。
  #
  # ⚠ ListenerDaemonTest と分けてあるのは、あちらが「streaming の使える環境か」で
  # 丸ごと disable になるから。ここで見るのは pid ファイルの読み方だけで、環境に依らない。
  class ListenerDaemonHealthTest < TestCase
    def setup
      @dir = Dir.mktmpdir
      @pid_path = File.join(@dir, 'ListenerDaemon.pid')
      @stubs = {}
      path = @pid_path
      stub(:pid_path) {path}
      stub(:check_streaming_endpoint) {nil}
    end

    def teardown
      Environment.define_singleton_method(:mastodon?, @mastodon) if @mastodon
      @stubs.each do |name, original|
        if original
          ListenerDaemon.define_singleton_method(name, original)
        else
          ListenerDaemon.singleton_class.send(:remove_method, name)
        end
      end
      FileUtils.rm_rf(@dir)
    end

    def test_live_pid_is_ok
      File.write(@pid_path, Process.pid.to_s)

      assert_equal('OK', ListenerDaemon.health[:status])
    end

    # ⚠ **pid ファイルが無ければ pgrep へ倒す。**`exist?` → `read` の間に消えた
    # （デーモン自身の TERM trap が消した直後）場合も同じ経路を通ること。
    # 以前は `Errno::ENOENT` が総括 rescue に落ち、pgrep を試さずに NG だった。
    def test_missing_pid_file_falls_back_to_pgrep
      stub(:system) {|*| true}

      assert_equal('OK', ListenerDaemon.health[:status])
    end

    def test_missing_pid_file_without_process_is_ng
      stub(:system) {|*| false}
      health = ListenerDaemon.health

      assert_equal('NG', health[:status])
      assert_equal('listener process not found', health[:error])
    end

    # ⚠⚠ **壊れた pid ファイルを OK と言わない。**空・切り詰め・非数値だと `to_i` が 0 に
    # なり、`Process.kill(0, 0)` は自プロセスグループへの存在確認として成功する。
    def test_broken_pid_file_is_ng
      ['', 'garbage', "\n"].each do |content|
        File.write(@pid_path, content)

        assert_equal('NG', ListenerDaemon.health[:status], "pid ファイルが #{content.inspect}")
      end
    end

    # ⚠⚠ **自サーバーの名前が引けないだけなら NG にしない (#4821)。**NG は health 全体を
    # 503 にし、monit が再起動する。名前解決の失敗は再起動しても直らない。
    # ⚠ gem は `Socket::ResolutionError` を `GatewayError` に包むので、その形で投げる。
    def test_name_resolution_failure_is_not_ng
      as_mastodon
      File.write(@pid_path, Process.pid.to_s)
      error = wrapped(Socket::ResolutionError.new('getaddrinfo(3): Name does not resolve'))
      stub(:check_streaming_endpoint) {raise error}
      health = ListenerDaemon.health

      assert_equal('OK', health[:status])
      assert(health[:unresolved])
      assert_includes(health[:error], 'Name does not resolve')
    end

    # ⚠ 外すのは名前解決だけ。繋がって 5xx・接続拒否は NG のまま（修正を広げすぎない）。
    def test_other_streaming_failures_stay_ng
      as_mastodon
      File.write(@pid_path, Process.pid.to_s)
      [RuntimeError.new('streaming returned 502'), wrapped(Errno::ECONNREFUSED.new)].each do |error|
        stub(:check_streaming_endpoint) {raise error}
        health = ListenerDaemon.health

        assert_equal('NG', health[:status], error.message)
        assert_nil(health[:unresolved])
      end
    end

    # ⚠ listener が居ないのに「名前が引けないだけ」と読まない（生死の確認が先）。
    def test_dead_listener_is_ng_even_if_unresolvable
      stub(:system) {|*| false}
      error = wrapped(Socket::ResolutionError.new('getaddrinfo'))
      stub(:check_streaming_endpoint) {raise error}

      assert_equal('NG', ListenerDaemon.health[:status])
    end

    def test_name_resolution_error?
      assert(ListenerDaemon.name_resolution_error?(wrapped(Socket::ResolutionError.new('x'))))
      assert(ListenerDaemon.name_resolution_error?(SocketError.new('getaddrinfo: Name or service not known')))
      assert(ListenerDaemon.name_resolution_error?(Ginseng::GatewayError.new('Failed to open TCP connection to a:443 (getaddrinfo(3): x)')))
      assert_false(ListenerDaemon.name_resolution_error?(wrapped(Errno::ECONNREFUSED.new)))
      assert_false(ListenerDaemon.name_resolution_error?(RuntimeError.new('streaming returned 503')))
    end

    private

    # ⚠ ストリーミングの確認は Mastodon 系だけが通る。**omit にしない** — Misskey 系の CI で
    # 実行されないテストが増える（omission の上限・#4503）。判定だけ Mastodon に固定する。
    def as_mastodon
      @mastodon ||= Environment.method(:mastodon?)
      Environment.define_singleton_method(:mastodon?) {true}
    end

    # gem の HTTP と同じ形（元の例外を `cause` に持つ `GatewayError`）を作る。
    def wrapped(cause)
      begin
        raise cause
      rescue
        raise Ginseng::GatewayError, "Failed to open TCP connection (#{cause.message})"
      end
    rescue Ginseng::GatewayError => e
      return e
    end

    def stub(name, &)
      unless @stubs.key?(name)
        @stubs[name] = ListenerDaemon.singleton_methods(false).include?(name) ? ListenerDaemon.method(name) : nil
      end
      ListenerDaemon.define_singleton_method(name, &)
    end
  end
end
